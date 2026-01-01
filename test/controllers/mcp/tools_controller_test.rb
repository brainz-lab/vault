# frozen_string_literal: true

require "test_helper"

module Mcp
  class ToolsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @project = projects(:acme)
      @environment = secret_environments(:acme_development)
      @token, @raw_token = create_token_with_raw_value(
        project: @project,
        permissions: %w[read write admin]
      )
    end

    # ===========================================
    # Authentication
    # ===========================================

    test "index requires authentication" do
      get mcp_tools_path
      assert_response :unauthorized
    end

    test "index accepts Bearer token authentication" do
      get mcp_tools_path, headers: auth_headers
      assert_response :success
    end

    test "index accepts X-API-Key authentication" do
      get mcp_tools_path, headers: { "X-API-Key" => @raw_token }
      assert_response :success
    end

    # ===========================================
    # GET /mcp/tools (index)
    # ===========================================

    test "index returns list of tools" do
      get mcp_tools_path, headers: auth_headers
      assert_response :success
      assert json_response["tools"].is_a?(Array)
    end

    test "index includes expected tools" do
      get mcp_tools_path, headers: auth_headers
      assert_response :success

      tool_names = json_response["tools"].map { |t| t["name"] }
      assert_includes tool_names, "vault_list_secrets"
      assert_includes tool_names, "vault_get_secret"
      assert_includes tool_names, "vault_set_secret"
    end

    # ===========================================
    # POST /mcp/tools/:name (call)
    # ===========================================

    test "call executes tool with valid params" do
      post "/mcp/tools/vault_list_secrets",
           params: {}.to_json,
           headers: auth_headers.merge("Content-Type" => "application/json")

      assert_response :success
    end

    test "call returns error for unknown tool" do
      post "/mcp/tools/unknown_tool",
           params: {}.to_json,
           headers: auth_headers.merge("Content-Type" => "application/json")

      assert_response :bad_request
    end

    # ===========================================
    # POST /mcp/rpc (rpc)
    # ===========================================

    test "rpc handles tools/list method" do
      post mcp_rpc_path,
           params: { method: "tools/list", params: {} }.to_json,
           headers: auth_headers.merge("Content-Type" => "application/json")

      assert_response :success
      assert json_response["tools"].is_a?(Array)
    end

    test "rpc handles tools/call method" do
      post mcp_rpc_path,
           params: {
             method: "tools/call",
             params: { name: "vault_list_secrets", arguments: {} }
           }.to_json,
           headers: auth_headers.merge("Content-Type" => "application/json")

      assert_response :success
    end

    private

    def auth_headers
      { "Authorization" => "Bearer #{@raw_token}" }
    end
  end
end
