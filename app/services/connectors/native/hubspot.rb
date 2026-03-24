# frozen_string_literal: true

module Connectors
  module Native
    class Hubspot < Base
      def self.piece_name = "hubspot"
      def self.display_name = "HubSpot"
      def self.description = "Manage contacts, deals, and companies in HubSpot CRM"
      def self.category = "crm"
      def self.logo_url = "https://cdn.brainzlab.ai/connectors/hubspot.svg"
      def self.auth_type = "OAUTH2"

      def self.auth_schema
        {
          type: "OAUTH2",
          authUrl: "https://app.hubspot.com/oauth/authorize",
          tokenUrl: "https://api.hubapi.com/oauth/v1/token",
          scope: "crm.objects.contacts.read crm.objects.contacts.write crm.objects.deals.read crm.objects.deals.write crm.objects.companies.read",
          pkce: false
        }
      end

      def self.setup_guide
        {
          steps: [
            "Go to https://developers.hubspot.com and create a developer account",
            "Apps > Create app",
            "Auth tab > Add Redirect URL: {VAULT_URL}/oauth/callback",
            "Add required scopes: crm.objects.contacts.read, crm.objects.contacts.write, crm.objects.deals.read",
            "Copy Client ID and Client Secret from the Auth tab",
            "Set ENV: VAULT_OAUTH_HUBSPOT_CLIENT_ID and VAULT_OAUTH_HUBSPOT_CLIENT_SECRET"
          ],
          docs_url: "https://developers.hubspot.com/docs/api/oauth-quickstart-guide"
        }
      end

      def self.actions
        [
          { "name" => "list_contacts", "displayName" => "List Contacts", "description" => "List CRM contacts",
            "props" => { "limit" => { "type" => "number", "required" => false, "description" => "Max results (default: 20)" } } },
          { "name" => "create_contact", "displayName" => "Create Contact", "description" => "Create a new CRM contact",
            "props" => { "email" => { "type" => "string", "required" => true }, "firstname" => { "type" => "string", "required" => false },
              "lastname" => { "type" => "string", "required" => false }, "phone" => { "type" => "string", "required" => false } } },
          { "name" => "list_deals", "displayName" => "List Deals", "description" => "List CRM deals",
            "props" => { "limit" => { "type" => "number", "required" => false } } },
          { "name" => "create_deal", "displayName" => "Create Deal", "description" => "Create a new CRM deal",
            "props" => { "dealname" => { "type" => "string", "required" => true }, "amount" => { "type" => "string", "required" => false },
              "pipeline" => { "type" => "string", "required" => false }, "dealstage" => { "type" => "string", "required" => false } } }
        ]
      end

      API = "https://api.hubapi.com"

      def execute(action, **params)
        case action.to_s
        when "list_contacts" then api_get("/crm/v3/objects/contacts?limit=#{params[:limit] || 20}")
        when "create_contact" then api_post("/crm/v3/objects/contacts", { properties: params.slice(:email, :firstname, :lastname, :phone).compact })
        when "list_deals" then api_get("/crm/v3/objects/deals?limit=#{params[:limit] || 20}")
        when "create_deal" then api_post("/crm/v3/objects/deals", { properties: params.slice(:dealname, :amount, :pipeline, :dealstage).compact })
        else raise Connectors::ActionNotFoundError, "Unknown HubSpot action: #{action}"
        end
      end

      private

      def access_token = credentials[:access_token] || raise(Connectors::AuthenticationError, "No access token")

      def api_get(path)
        resp = faraday.get("#{API}#{path}") { |r| r.headers["Authorization"] = "Bearer #{access_token}" }
        handle(resp)
      end

      def api_post(path, body)
        resp = faraday.post("#{API}#{path}") { |r| r.headers["Authorization"] = "Bearer #{access_token}"; r.headers["Content-Type"] = "application/json"; r.body = body.to_json }
        handle(resp)
      end

      def handle(resp)
        raise Connectors::AuthenticationError, "HubSpot: unauthorized" if resp.status == 401
        data = JSON.parse(resp.body)
        raise Connectors::Error, "HubSpot API error (#{resp.status}): #{data['message']}" unless resp.success?
        data
      end

      def faraday = @faraday ||= Faraday.new { |f| f.options.timeout = 15; f.options.open_timeout = 5 }
    end
  end
end
