require "rails_helper"

RSpec.describe "Api::V1::AccessTokens", type: :request do
  let(:project) { create(:project) }
  let(:admin_token) { create(:access_token, project: project, permissions: %w[read write admin], environments: ["development"]) }
  let(:headers) { authenticated_json_headers(admin_token.plain_token) }

  describe "authentication" do
    it "returns unauthorized without a token" do
      get "/api/v1/access_tokens", headers: json_headers
      expect(response).to have_http_status(:unauthorized)
    end

    it "authenticates with a valid admin token" do
      get "/api/v1/access_tokens", headers: headers
      expect(response).to have_http_status(:success)
    end

    it "requires admin permission" do
      read_token = create(:access_token, project: project, permissions: %w[read], environments: ["development"])

      get "/api/v1/access_tokens",
        headers: authenticated_json_headers(read_token.plain_token)

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "GET /api/v1/access_tokens" do
    it "returns a list of tokens" do
      create(:access_token, project: project, name: "CI Token", permissions: %w[read])
      create(:access_token, project: project, name: "Deploy Token", permissions: %w[read write])

      get "/api/v1/access_tokens", headers: headers

      expect(response).to have_http_status(:success)

      body = json_response
      # The admin_token plus the two we just created
      expect(body["tokens"].length).to eq(3)
      names = body["tokens"].map { |t| t["name"] }
      expect(names).to include("CI Token", "Deploy Token")
    end
  end

  describe "POST /api/v1/access_tokens" do
    it "creates a new token and returns the raw token value" do
      expect {
        post "/api/v1/access_tokens",
          params: { name: "New Token", permissions: %w[read write] },
          headers: headers
      }.to change(AccessToken, :count).by(1)

      expect(response).to have_http_status(:created)

      body = json_response
      expect(body["name"]).to eq("New Token")
      expect(body["permissions"]).to eq(%w[read write])
      expect(body["token"]).to be_present
    end

    it "requires admin permission to create tokens" do
      write_token = create(:access_token, project: project, permissions: %w[read write], environments: ["development"])

      post "/api/v1/access_tokens",
        params: { name: "Sneaky Token", permissions: %w[read] },
        headers: authenticated_json_headers(write_token.plain_token)

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "GET /api/v1/access_tokens/:id" do
    it "returns token details" do
      other_token = create(:access_token, project: project, name: "Detail Token", permissions: %w[read])

      get "/api/v1/access_tokens/#{other_token.id}", headers: headers

      expect(response).to have_http_status(:success)

      body = json_response
      expect(body["name"]).to eq("Detail Token")
      expect(body["permissions"]).to eq(%w[read])
      expect(body["active"]).to be(true)
      # Raw token should NOT be returned on show
      expect(body["token"]).to be_nil
    end
  end

  describe "DELETE /api/v1/access_tokens/:id" do
    it "revokes the token" do
      target_token = create(:access_token, project: project, name: "Revoke Me", permissions: %w[read])

      delete "/api/v1/access_tokens/#{target_token.id}", headers: headers

      expect(response).to have_http_status(:no_content)
      expect(target_token.reload.active).to be(false)
      expect(target_token.revoked_at).to be_present
    end
  end
end
