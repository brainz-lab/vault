# frozen_string_literal: true

module Connectors
  module Native
    class Airtable < Base
      def self.piece_name = "airtable"
      def self.display_name = "Airtable"
      def self.description = "Read, create, and update records in Airtable bases"
      def self.category = "productivity"
      def self.logo_url = "https://cdn.brainzlab.ai/connectors/airtable.svg"
      def self.auth_type = "OAUTH2"

      def self.auth_schema
        {
          type: "OAUTH2",
          authUrl: "https://airtable.com/oauth2/v1/authorize",
          tokenUrl: "https://airtable.com/oauth2/v1/token",
          scope: "data.records:read data.records:write schema.bases:read",
          pkce: true
        }
      end

      def self.setup_guide
        {
          steps: [
            "Go to https://airtable.com/create/oauth",
            "Create new OAuth integration",
            "Redirect URLs: {VAULT_URL}/oauth/callback",
            "Scopes: data.records:read, data.records:write, schema.bases:read",
            "Copy Client ID and Client Secret",
            "Set ENV: VAULT_OAUTH_AIRTABLE_CLIENT_ID and VAULT_OAUTH_AIRTABLE_CLIENT_SECRET"
          ],
          docs_url: "https://airtable.com/developers/web/guides/oauth-integrations"
        }
      end

      def self.actions
        [
          { "name" => "list_bases", "displayName" => "List Bases", "description" => "List accessible Airtable bases", "props" => {} },
          { "name" => "list_records", "displayName" => "List Records", "description" => "List records from a table",
            "props" => { "base_id" => { "type" => "string", "required" => true }, "table_name" => { "type" => "string", "required" => true },
              "max_records" => { "type" => "number", "required" => false } } },
          { "name" => "create_record", "displayName" => "Create Record", "description" => "Create a record in a table",
            "props" => { "base_id" => { "type" => "string", "required" => true }, "table_name" => { "type" => "string", "required" => true },
              "fields" => { "type" => "json", "required" => true, "description" => 'JSON object of field values {"Name": "value"}' } } },
          { "name" => "update_record", "displayName" => "Update Record", "description" => "Update a record by ID",
            "props" => { "base_id" => { "type" => "string", "required" => true }, "table_name" => { "type" => "string", "required" => true },
              "record_id" => { "type" => "string", "required" => true }, "fields" => { "type" => "json", "required" => true } } }
        ]
      end

      API = "https://api.airtable.com/v0"

      def execute(action, **params)
        case action.to_s
        when "list_bases" then api_get("https://api.airtable.com/v0/meta/bases")
        when "list_records" then api_get("#{API}/#{params[:base_id]}/#{ERB::Util.url_encode(params[:table_name])}?maxRecords=#{params[:max_records] || 100}")
        when "create_record"
          fields = params[:fields].is_a?(String) ? JSON.parse(params[:fields]) : params[:fields]
          api_post("#{API}/#{params[:base_id]}/#{ERB::Util.url_encode(params[:table_name])}", { fields: fields })
        when "update_record"
          fields = params[:fields].is_a?(String) ? JSON.parse(params[:fields]) : params[:fields]
          api_patch("#{API}/#{params[:base_id]}/#{ERB::Util.url_encode(params[:table_name])}/#{params[:record_id]}", { fields: fields })
        else raise Connectors::ActionNotFoundError, "Unknown Airtable action: #{action}"
        end
      end

      private

      def access_token = credentials[:access_token] || raise(Connectors::AuthenticationError, "No access token")

      def api_get(url)
        resp = faraday.get(url) { |r| r.headers["Authorization"] = "Bearer #{access_token}" }
        handle(resp)
      end

      def api_post(url, body)
        resp = faraday.post(url) { |r| r.headers["Authorization"] = "Bearer #{access_token}"; r.headers["Content-Type"] = "application/json"; r.body = body.to_json }
        handle(resp)
      end

      def api_patch(url, body)
        resp = faraday.patch(url) { |r| r.headers["Authorization"] = "Bearer #{access_token}"; r.headers["Content-Type"] = "application/json"; r.body = body.to_json }
        handle(resp)
      end

      def handle(resp)
        raise Connectors::AuthenticationError, "Airtable: unauthorized" if resp.status == 401
        data = JSON.parse(resp.body)
        raise Connectors::Error, "Airtable API error (#{resp.status}): #{data.dig('error', 'message')}" unless resp.success?
        data
      end

      def faraday = @faraday ||= Faraday.new { |f| f.options.timeout = 15; f.options.open_timeout = 5 }
    end
  end
end
