require "rails_helper"

RSpec.describe "Mcp::Tools", type: :request do
  let(:project) { create(:project) }
  let(:token) { create(:access_token, project: project, permissions: %w[read write admin], environments: [ "development" ]) }
  let(:headers) { authenticated_json_headers(token.plain_token) }

  describe "authentication" do
    it "returns unauthorized without a token" do
      get "/mcp/tools", headers: json_headers
      expect(response).to have_http_status(:unauthorized)
    end

    it "authenticates with Bearer token" do
      get "/mcp/tools", headers: headers
      expect(response).to have_http_status(:success)
    end

    it "authenticates with X-API-Key header" do
      get "/mcp/tools", headers: json_headers.merge("X-API-Key" => token.plain_token)
      expect(response).to have_http_status(:success)
    end

    it "authenticates with project API key" do
      get "/mcp/tools", headers: json_headers.merge("Authorization" => "Bearer #{project.api_key}")
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /mcp/tools" do
    it "returns the list of available tools" do
      get "/mcp/tools", headers: headers

      expect(response).to have_http_status(:success)

      body = json_response
      expect(body["tools"]).to be_an(Array)
      expect(body["tools"].length).to be > 0

      tool_names = body["tools"].map { |t| t["name"] }
      expect(tool_names).to include(
        "vault_list_secrets",
        "vault_get_secret",
        "vault_set_secret",
        "vault_delete_secret",
        "vault_list_environments",
        "vault_get_history",
        "vault_export",
        "vault_import"
      )
    end

    it "returns tools with description and inputSchema" do
      get "/mcp/tools", headers: headers

      body = json_response
      body["tools"].each do |tool|
        expect(tool).to have_key("name")
        expect(tool).to have_key("description")
        expect(tool).to have_key("inputSchema")
      end
    end
  end

  describe "POST /mcp/tools/:name" do
    it "executes a tool" do
      create(:secret, project: project, key: "MCP_TEST_SECRET")

      post "/mcp/tools/vault_list_secrets",
        params: { environment: "development" }.to_json,
        headers: headers

      expect(response).to have_http_status(:success)
    end

    it "returns error for unknown tool" do
      post "/mcp/tools/nonexistent_tool",
        params: { environment: "development" }.to_json,
        headers: headers

      expect(response).to have_http_status(:bad_request)
      expect(json_response["error"]).to include("Unknown tool")
    end
  end

  describe "POST /mcp/rpc" do
    it "handles tools/list method" do
      post "/mcp/rpc",
        params: { method: "tools/list" }.to_json,
        headers: headers

      expect(response).to have_http_status(:success)

      body = json_response
      expect(body["tools"]).to be_an(Array)
      expect(body["tools"].length).to be > 0
    end

    it "handles tools/call method" do
      create(:secret, project: project, key: "RPC_SECRET")

      post "/mcp/rpc",
        params: {
          method: "tools/call",
          params: { name: "vault_list_secrets", environment: "development" }
        }.to_json,
        headers: headers

      expect(response).to have_http_status(:success)
    end
  end
end
