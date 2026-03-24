# frozen_string_literal: true

module Connectors
  module Native
    class Notion < Base
      def self.piece_name = "notion"
      def self.display_name = "Notion"
      def self.description = "Read and update pages, databases, and blocks in Notion"
      def self.category = "productivity"
      def self.logo_url = "https://cdn.brainzlab.ai/connectors/notion.svg"
      def self.auth_type = "OAUTH2"

      def self.auth_schema
        {
          type: "OAUTH2",
          authUrl: "https://api.notion.com/v1/oauth/authorize?owner=user",
          tokenUrl: "https://api.notion.com/v1/oauth/token",
          scope: "",
          pkce: false
        }
      end

      def self.setup_guide
        {
          steps: [
            "Go to https://www.notion.so/my-integrations",
            "Create a new integration with type: Public (required for OAuth)",
            "Add Redirect URI: {VAULT_URL}/oauth/callback",
            "Set capabilities: Read content, Update content, Insert content",
            "Copy OAuth client ID and OAuth client secret",
            "Set ENV: VAULT_OAUTH_NOTION_CLIENT_ID and VAULT_OAUTH_NOTION_CLIENT_SECRET"
          ],
          docs_url: "https://developers.notion.com/docs/authorization"
        }
      end

      def self.actions
        [
          { "name" => "search", "displayName" => "Search", "description" => "Search pages and databases",
            "props" => { "query" => { "type" => "string", "required" => false }, "filter" => { "type" => "string", "required" => false, "description" => "page or database" } } },
          { "name" => "get_page", "displayName" => "Get Page", "description" => "Retrieve a page by ID",
            "props" => { "page_id" => { "type" => "string", "required" => true } } },
          { "name" => "create_page", "displayName" => "Create Page", "description" => "Create a new page in a database",
            "props" => { "database_id" => { "type" => "string", "required" => true }, "properties" => { "type" => "json", "required" => true, "description" => "Page properties JSON" } } },
          { "name" => "query_database", "displayName" => "Query Database", "description" => "Query a Notion database",
            "props" => { "database_id" => { "type" => "string", "required" => true }, "filter" => { "type" => "json", "required" => false } } }
        ]
      end

      API = "https://api.notion.com/v1"

      def execute(action, **params)
        case action.to_s
        when "search" then api_post("/search", { query: params[:query], filter: params[:filter] ? { value: params[:filter], property: "object" } : nil }.compact)
        when "get_page" then api_get("/pages/#{params[:page_id]}")
        when "create_page"
          props = params[:properties].is_a?(String) ? JSON.parse(params[:properties]) : params[:properties]
          api_post("/pages", { parent: { database_id: params[:database_id] }, properties: props })
        when "query_database"
          body = {}
          body[:filter] = (params[:filter].is_a?(String) ? JSON.parse(params[:filter]) : params[:filter]) if params[:filter].present?
          api_post("/databases/#{params[:database_id]}/query", body)
        else raise Connectors::ActionNotFoundError, "Unknown Notion action: #{action}"
        end
      end

      private

      def access_token = credentials[:access_token] || raise(Connectors::AuthenticationError, "No access token")

      def api_get(path)
        resp = faraday.get("#{API}#{path}") { |r| r.headers["Authorization"] = "Bearer #{access_token}"; r.headers["Notion-Version"] = "2022-06-28" }
        handle(resp)
      end

      def api_post(path, body)
        resp = faraday.post("#{API}#{path}") { |r| r.headers["Authorization"] = "Bearer #{access_token}"; r.headers["Notion-Version"] = "2022-06-28"; r.headers["Content-Type"] = "application/json"; r.body = body.to_json }
        handle(resp)
      end

      def handle(resp)
        raise Connectors::AuthenticationError, "Notion: unauthorized" if resp.status == 401
        data = JSON.parse(resp.body)
        raise Connectors::Error, "Notion API error: #{data['message']}" unless resp.success?
        data
      end

      def faraday = @faraday ||= Faraday.new { |f| f.options.timeout = 15; f.options.open_timeout = 5 }
    end
  end
end
