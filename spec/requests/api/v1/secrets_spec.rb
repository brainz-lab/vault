require "rails_helper"

RSpec.describe "Api::V1::Secrets", type: :request do
  let(:project) { create(:project) }
  let(:dev_environment) { project.secret_environments.find_by(slug: "development") }
  let(:token) { create(:access_token, project: project, permissions: %w[read write admin], environments: [ "development" ]) }
  let(:headers) { authenticated_json_headers(token.plain_token) }

  describe "authentication" do
    it "returns unauthorized without a token" do
      get "/api/v1/secrets", headers: json_headers
      expect(response).to have_http_status(:unauthorized)
    end

    it "authenticates with Bearer token" do
      get "/api/v1/secrets", headers: headers
      expect(response).to have_http_status(:success)
    end

    it "authenticates with X-API-Key header" do
      get "/api/v1/secrets", headers: json_headers.merge("X-API-Key" => token.plain_token)
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /api/v1/secrets" do
    it "returns a list of secrets" do
      secret1 = create(:secret, project: project, key: "DB_HOST")
      secret2 = create(:secret, project: project, key: "DB_PASS")

      get "/api/v1/secrets", headers: headers
      expect(response).to have_http_status(:success)

      body = json_response
      expect(body["secrets"].length).to eq(2)
      keys = body["secrets"].map { |s| s["key"] }
      expect(keys).to include("DB_HOST", "DB_PASS")
      expect(body["total"]).to eq(2)
    end

    it "filters secrets by folder" do
      folder = create(:secret_folder, project: project, name: "database")
      create(:secret, project: project, key: "IN_FOLDER", secret_folder: folder)
      create(:secret, project: project, key: "NOT_IN_FOLDER")

      get "/api/v1/secrets", params: { folder: folder.path }, headers: headers
      expect(response).to have_http_status(:success)

      body = json_response
      keys = body["secrets"].map { |s| s["key"] }
      expect(keys).to include("IN_FOLDER")
      expect(keys).not_to include("NOT_IN_FOLDER")
    end

    it "creates an audit log entry" do
      expect {
        get "/api/v1/secrets", headers: headers
      }.to change(AuditLog, :count).by(1)

      log = AuditLog.last
      expect(log.action).to eq("list_secrets")
      expect(log.project).to eq(project)
    end
  end

  describe "GET /api/v1/secrets/:key" do
    let(:secret) { create(:secret, project: project, key: "MY_SECRET") }

    before do
      create(:secret_version,
        secret: secret,
        secret_environment: dev_environment,
        plaintext_value: "super_secret_value"
      )
    end

    it "returns the secret value" do
      get "/api/v1/secrets/#{secret.key}",
        params: { environment: "development" },
        headers: headers

      expect(response).to have_http_status(:success)

      body = json_response
      expect(body["key"]).to eq("MY_SECRET")
      expect(body["value"]).to eq("super_secret_value")
      expect(body["environment"]).to eq("development")
    end

    it "returns 404 for a non-existent secret" do
      get "/api/v1/secrets/DOES_NOT_EXIST",
        params: { environment: "development" },
        headers: headers

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /api/v1/secrets" do
    it "creates a new secret" do
      expect {
        post "/api/v1/secrets",
          params: { key: "NEW_KEY", value: "new_value", environment: "development" },
          headers: headers
      }.to change(Secret, :count).by(1)

      expect(response).to have_http_status(:created)

      body = json_response
      expect(body["key"]).to eq("NEW_KEY")
      expect(body["environment"]).to eq("development")
    end

    it "requires write permission" do
      read_token = create(:access_token, project: project, permissions: %w[read], environments: [ "development" ])

      post "/api/v1/secrets",
        params: { key: "NEW_KEY", value: "new_value", environment: "development" },
        headers: authenticated_json_headers(read_token.plain_token)

      expect(response).to have_http_status(:forbidden)
    end

    it "updates an existing secret when key already exists" do
      existing = create(:secret, project: project, key: "EXISTING_KEY")
      create(:secret_version,
        secret: existing,
        secret_environment: dev_environment,
        plaintext_value: "old_value"
      )

      expect {
        post "/api/v1/secrets",
          params: { key: "EXISTING_KEY", value: "updated_value", environment: "development" },
          headers: headers
      }.not_to change(Secret, :count)

      expect(response).to have_http_status(:created)
    end
  end

  describe "PUT /api/v1/secrets/:key" do
    let(:secret) { create(:secret, project: project, key: "UPDATE_ME") }

    before do
      create(:secret_version,
        secret: secret,
        secret_environment: dev_environment,
        plaintext_value: "original"
      )
    end

    it "updates the secret metadata" do
      put "/api/v1/secrets/#{secret.key}",
        params: { description: "Updated description", environment: "development" },
        headers: headers

      expect(response).to have_http_status(:success)
      expect(secret.reload.description).to eq("Updated description")
    end

    it "requires write permission" do
      read_token = create(:access_token, project: project, permissions: %w[read], environments: [ "development" ])

      put "/api/v1/secrets/#{secret.key}",
        params: { description: "No access", environment: "development" },
        headers: authenticated_json_headers(read_token.plain_token)

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "DELETE /api/v1/secrets/:key" do
    let!(:secret) { create(:secret, project: project, key: "DELETE_ME") }

    it "archives the secret" do
      delete "/api/v1/secrets/#{secret.key}", headers: headers

      expect(response).to have_http_status(:no_content)
      expect(secret.reload.archived).to be(true)
    end

    it "requires admin permission" do
      write_token = create(:access_token, project: project, permissions: %w[read write], environments: [ "development" ])

      delete "/api/v1/secrets/#{secret.key}",
        headers: authenticated_json_headers(write_token.plain_token)

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "GET /api/v1/secrets/:key/versions" do
    let(:secret) { create(:secret, project: project, key: "VERSIONED") }

    before do
      create(:secret_version,
        secret: secret,
        secret_environment: dev_environment,
        version: 1,
        plaintext_value: "v1_value"
      )
      create(:secret_version,
        secret: secret,
        secret_environment: dev_environment,
        version: 2,
        current: true,
        plaintext_value: "v2_value"
      )
    end

    it "returns version history" do
      get "/api/v1/secrets/#{secret.key}/versions", headers: headers

      expect(response).to have_http_status(:success)

      body = json_response
      expect(body["key"]).to eq("VERSIONED")
      expect(body["versions"].length).to eq(2)
      expect(body["versions"].first["version"]).to be > body["versions"].last["version"]
    end
  end

  describe "POST /api/v1/secrets/:key/rollback" do
    let(:secret) { create(:secret, project: project, key: "ROLLBACK_ME") }

    before do
      create(:secret_version,
        secret: secret,
        secret_environment: dev_environment,
        version: 1,
        plaintext_value: "v1_value"
      )
      create(:secret_version,
        secret: secret,
        secret_environment: dev_environment,
        version: 2,
        current: true,
        plaintext_value: "v2_value"
      )
    end

    it "returns 404 for an invalid version" do
      post "/api/v1/secrets/#{secret.key}/rollback",
        params: { version: 999, environment: "development" },
        headers: headers

      expect(response).to have_http_status(:not_found)
    end
  end
end
