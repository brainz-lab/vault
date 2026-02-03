module Mcp
  class ToolsController < ApplicationController
    before_action :authenticate!

    # GET /mcp/tools
    def index
      render json: {
        tools: mcp_server.tools
      }
    end

    # POST /mcp/tools/:name
    def call
      tool_name = params[:name]
      tool_params = parse_json_body

      result = mcp_server.call(tool_name, tool_params.symbolize_keys)

      render json: result
    rescue ArgumentError => e
      render json: { error: e.message }, status: :bad_request
    end

    # POST /mcp/rpc
    def rpc
      body = parse_json_body
      method = body[:method] || body["method"]
      rpc_params = body[:params] || body["params"] || {}

      result = mcp_server.rpc(method, rpc_params.symbolize_keys)

      render json: result
    end

    private

    def authenticate!
      raw_token = extract_token
      return render json: { error: "Unauthorized" }, status: :unauthorized unless raw_token

      # Try project API key first (vlt_api_xxx format)
      if raw_token.start_with?("vlt_api_")
        @current_project = Project.find_by(api_key: raw_token)
        return render json: { error: "Unauthorized" }, status: :unauthorized unless @current_project
        return
      end

      # Fall back to AccessToken authentication
      @current_token = authenticate_token(raw_token)
      @current_project = @current_token&.project

      unless @current_project
        render json: { error: "Unauthorized" }, status: :unauthorized
      end
    end

    def authenticate_token(raw_token)
      return nil unless raw_token

      # Token prefix is the first 8 characters of the raw token
      prefix = raw_token[0, 8]
      return nil unless prefix&.length == 8

      AccessToken.active.where(token_prefix: prefix).find_each do |token|
        if token.authenticate(raw_token)
          return token
        end
      end

      nil
    end

    def extract_token
      auth_header = request.headers["Authorization"]
      if auth_header&.start_with?("Bearer ")
        return auth_header[7..]
      end

      api_key = request.headers["X-API-Key"]
      return api_key if api_key.present?

      nil
    end

    def mcp_server
      @mcp_server ||= ::Mcp::Server.new(
        project: @current_project,
        environment: resolve_environment
      )
    end

    def resolve_environment
      slug = params[:environment] || request.headers["X-Vault-Environment"] || "development"
      @current_project.secret_environments.find_by(slug: slug)
    end

    def parse_json_body
      return {} if request.raw_post.blank?

      JSON.parse(request.raw_post, symbolize_names: true)
    rescue JSON::ParserError
      {}
    end
  end
end
