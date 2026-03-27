require "rails_helper"

RSpec.describe "Api::V1::Environments", type: :request do
  let(:project) { create(:project) }
  let(:token) { create(:access_token, project: project, permissions: %w[read write admin], environments: [ "development" ]) }
  let(:headers) { authenticated_json_headers(token.plain_token) }

  describe "authentication" do
    it "returns unauthorized without a token" do
      get "/api/v1/environments", headers: json_headers
      expect(response).to have_http_status(:unauthorized)
    end

    it "authenticates with a valid token" do
      get "/api/v1/environments", headers: headers
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /api/v1/environments" do
    it "returns the list of environments" do
      get "/api/v1/environments", headers: headers

      expect(response).to have_http_status(:success)

      body = json_response
      # Project creates 3 default environments: development, staging, production
      expect(body["environments"].length).to eq(3)
      slugs = body["environments"].map { |e| e["slug"] }
      expect(slugs).to include("development", "staging", "production")
    end

    it "returns environments ordered by position" do
      get "/api/v1/environments", headers: headers

      body = json_response
      positions = body["environments"].map { |e| e["position"] }
      expect(positions).to eq(positions.sort)
    end
  end

  describe "GET /api/v1/environments/:slug" do
    it "returns environment details" do
      get "/api/v1/environments/development", headers: headers

      expect(response).to have_http_status(:success)

      body = json_response
      expect(body["slug"]).to eq("development")
      expect(body["name"]).to eq("Development")
      expect(body).to have_key("secrets_count")
    end

    it "returns 404 for non-existent environment" do
      get "/api/v1/environments/nonexistent", headers: headers

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /api/v1/environments" do
    it "creates a new environment" do
      headers # force lazy evaluation before counting
      expect {
        post "/api/v1/environments",
          params: { name: "QA", slug: "qa", position: 5, color: "#3b82f6" },
          headers: headers
      }.to change(SecretEnvironment, :count).by(1)

      expect(response).to have_http_status(:created)

      body = json_response
      expect(body["name"]).to eq("QA")
      expect(body["slug"]).to eq("qa")
      expect(body["color"]).to eq("#3b82f6")
    end

    it "requires admin permission" do
      read_token = create(:access_token, project: project, permissions: %w[read], environments: [ "development" ])

      post "/api/v1/environments",
        params: { name: "QA", slug: "qa", position: 5 },
        headers: authenticated_json_headers(read_token.plain_token)

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "PUT /api/v1/environments/:slug" do
    it "updates the environment" do
      put "/api/v1/environments/development",
        params: { name: "Dev", color: "#10b981" },
        headers: headers

      expect(response).to have_http_status(:success)

      body = json_response
      expect(body["name"]).to eq("Dev")
      expect(body["color"]).to eq("#10b981")
    end

    it "requires admin permission" do
      read_token = create(:access_token, project: project, permissions: %w[read], environments: [ "development" ])

      put "/api/v1/environments/development",
        params: { name: "Dev" },
        headers: authenticated_json_headers(read_token.plain_token)

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "DELETE /api/v1/environments/:slug" do
    it "deletes an environment with no secrets" do
      env = create(:secret_environment, project: project, name: "Temp", slug: "temp", position: 99)

      expect {
        delete "/api/v1/environments/#{env.slug}", headers: headers
      }.to change(SecretEnvironment, :count).by(-1)

      expect(response).to have_http_status(:no_content)
    end

    it "returns unprocessable entity when environment has secrets" do
      dev_env = project.secret_environments.find_by(slug: "development")
      secret = create(:secret, project: project, key: "HAS_VALUE")
      create(:secret_version,
        secret: secret,
        secret_environment: dev_env,
        plaintext_value: "value"
      )

      delete "/api/v1/environments/development", headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_response["error"]).to include("Cannot delete environment with secrets")
    end

    it "requires admin permission" do
      read_token = create(:access_token, project: project, permissions: %w[read], environments: [ "development" ])

      delete "/api/v1/environments/development",
        headers: authenticated_json_headers(read_token.plain_token)

      expect(response).to have_http_status(:forbidden)
    end
  end
end
