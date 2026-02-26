module Connectors
  module Native
    class Bitrix < Base
      def self.piece_name = "bitrix"
      def self.display_name = "Bitrix24"
      def self.description = "CRM platform for contacts, deals, companies and leads management"
      def self.category = "crm"
      def self.auth_type = "CUSTOM_AUTH"
      def self.auth_schema
        {
          type: "CUSTOM_AUTH",
          props: {
            domain: { type: "string", required: true, description: "Bitrix24 domain (e.g. yourcompany.bitrix24.com)" },
            webhook_token: { type: "string", required: true, description: "Webhook token from the webhook URL (e.g. user_id/secret)" },
            auth_method: { type: "string", required: true, description: "Authentication method: webhook (default), oauth2, or token", default: "webhook" }
          }
        }
      end

      def self.logo_url
        "/images/connectors/bitrix.svg"
      end

      def self.setup_guide
        {
          title: "How to configure your Bitrix24 Inbound Webhook",
          steps: [
            { title: "Activate your Bitrix24 account", description: "You need an active Bitrix24 plan (even the free plan works). Go to bitrix24.com, sign up or log in, and make sure your account is active. If it's a new account, you may need to manually activate it." },
            { title: "Go to Developer Resources", description: "In your Bitrix24 portal, navigate to the left sidebar menu and look for 'Developer resources' (Recursos para Desarrolladores). If you don't see it, try logging out and back in." },
            { title: "Create an Inbound Webhook", description: "Inside Developer Resources, click 'Other' > 'Inbound webhook' (Webhook entrante). This creates a REST API endpoint for external apps to access your Bitrix24 data." },
            { title: "Set permissions (scopes)", description: "In the webhook configuration, under 'Assign permissions' (Asignar permisos), add the 'CRM (crm)' scope. This is required for contact, deal, lead, and company operations. You can also add 'user' scope for profile access." },
            { title: "Copy your webhook URL", description: "After saving, Bitrix24 shows a webhook URL like: https://b24-xxxxx.bitrix24.co/rest/1/your-token-here/. You need to split this into two parts for the configuration below." },
            { title: "Enter credentials", description: "From the webhook URL https://b24-xxxxx.bitrix24.co/rest/1/abc123token/: Domain = b24-xxxxx.bitrix24.co (just the domain, no https://). Webhook Token = 1/abc123token (the path after /rest/)." }
          ],
          tips: [
            "If the webhook option doesn't appear, log out of Bitrix24 completely and log back in",
            "The free Bitrix24 plan supports webhooks — you don't need a paid plan",
            "Each webhook has its own permissions. Make sure to add 'CRM' scope for contact/deal operations",
            "You can create multiple webhooks with different permissions for different integrations",
            "The webhook token never expires unless you regenerate it manually"
          ],
          credential_help: {
            "domain" => "Your Bitrix24 domain only (e.g. b24-hztli9.bitrix24.co). Do NOT include https:// or any path",
            "webhook_token" => "The token part from your webhook URL. For https://domain/rest/1/abc123/ the token is: 1/abc123",
            "auth_method" => "Leave as 'webhook' (default). Only change if using OAuth2 or token-based auth"
          }
        }
      end

      def self.actions
        [
          { "name" => "test_connection", "displayName" => "Test Connection", "description" => "Validate credentials against the Bitrix24 API", "props" => {} },
          # Contacts
          { "name" => "list_contacts", "displayName" => "List Contacts", "description" => "List contacts with optional filters",
            "props" => {
              "start" => { "type" => "integer", "required" => false, "description" => "Offset for pagination" },
              "filter" => { "type" => "object", "required" => false, "description" => "Filter criteria (e.g. {\"NAME\": \"John\"})" },
              "select" => { "type" => "array", "required" => false, "description" => "Fields to return" }
            } },
          { "name" => "get_contact", "displayName" => "Get Contact", "description" => "Get a contact by ID",
            "props" => { "id" => { "type" => "integer", "required" => true, "description" => "Contact ID" } } },
          { "name" => "create_contact", "displayName" => "Create Contact", "description" => "Create a new contact",
            "props" => {
              "fields" => { "type" => "object", "required" => true, "description" => "Contact fields (NAME, LAST_NAME, EMAIL, PHONE, etc.)" }
            } },
          { "name" => "update_contact", "displayName" => "Update Contact", "description" => "Update an existing contact",
            "props" => {
              "id" => { "type" => "integer", "required" => true, "description" => "Contact ID" },
              "fields" => { "type" => "object", "required" => true, "description" => "Fields to update" }
            } },
          # Deals
          { "name" => "list_deals", "displayName" => "List Deals", "description" => "List deals with optional filters",
            "props" => {
              "start" => { "type" => "integer", "required" => false, "description" => "Offset for pagination" },
              "filter" => { "type" => "object", "required" => false, "description" => "Filter criteria" },
              "select" => { "type" => "array", "required" => false, "description" => "Fields to return" }
            } },
          { "name" => "get_deal", "displayName" => "Get Deal", "description" => "Get a deal by ID",
            "props" => { "id" => { "type" => "integer", "required" => true, "description" => "Deal ID" } } },
          { "name" => "create_deal", "displayName" => "Create Deal", "description" => "Create a new deal",
            "props" => {
              "fields" => { "type" => "object", "required" => true, "description" => "Deal fields (TITLE, STAGE_ID, OPPORTUNITY, etc.)" }
            } },
          { "name" => "update_deal", "displayName" => "Update Deal", "description" => "Update an existing deal",
            "props" => {
              "id" => { "type" => "integer", "required" => true, "description" => "Deal ID" },
              "fields" => { "type" => "object", "required" => true, "description" => "Fields to update" }
            } },
          # Companies
          { "name" => "list_companies", "displayName" => "List Companies", "description" => "List companies with optional filters",
            "props" => {
              "start" => { "type" => "integer", "required" => false, "description" => "Offset for pagination" },
              "filter" => { "type" => "object", "required" => false, "description" => "Filter criteria" },
              "select" => { "type" => "array", "required" => false, "description" => "Fields to return" }
            } },
          { "name" => "get_company", "displayName" => "Get Company", "description" => "Get a company by ID",
            "props" => { "id" => { "type" => "integer", "required" => true, "description" => "Company ID" } } },
          { "name" => "create_company", "displayName" => "Create Company", "description" => "Create a new company",
            "props" => {
              "fields" => { "type" => "object", "required" => true, "description" => "Company fields (TITLE, INDUSTRY, REVENUE, etc.)" }
            } },
          { "name" => "update_company", "displayName" => "Update Company", "description" => "Update an existing company",
            "props" => {
              "id" => { "type" => "integer", "required" => true, "description" => "Company ID" },
              "fields" => { "type" => "object", "required" => true, "description" => "Fields to update" }
            } },
          # Leads
          { "name" => "list_leads", "displayName" => "List Leads", "description" => "List leads with optional filters",
            "props" => {
              "start" => { "type" => "integer", "required" => false, "description" => "Offset for pagination" },
              "filter" => { "type" => "object", "required" => false, "description" => "Filter criteria" },
              "select" => { "type" => "array", "required" => false, "description" => "Fields to return" }
            } },
          { "name" => "get_lead", "displayName" => "Get Lead", "description" => "Get a lead by ID",
            "props" => { "id" => { "type" => "integer", "required" => true, "description" => "Lead ID" } } },
          { "name" => "create_lead", "displayName" => "Create Lead", "description" => "Create a new lead",
            "props" => {
              "fields" => { "type" => "object", "required" => true, "description" => "Lead fields (TITLE, NAME, LAST_NAME, STATUS_ID, etc.)" }
            } },
          { "name" => "update_lead", "displayName" => "Update Lead", "description" => "Update an existing lead",
            "props" => {
              "id" => { "type" => "integer", "required" => true, "description" => "Lead ID" },
              "fields" => { "type" => "object", "required" => true, "description" => "Fields to update" }
            } }
        ]
      end

      def execute(action, **params)
        case action.to_s
        when "test_connection" then test_connection
        when "list_contacts" then list_entities("crm.contact.list", params)
        when "get_contact" then get_entity("crm.contact.get", params)
        when "create_contact" then create_entity("crm.contact.add", params)
        when "update_contact" then update_entity("crm.contact.update", params)
        when "list_deals" then list_entities("crm.deal.list", params)
        when "get_deal" then get_entity("crm.deal.get", params)
        when "create_deal" then create_entity("crm.deal.add", params)
        when "update_deal" then update_entity("crm.deal.update", params)
        when "list_companies" then list_entities("crm.company.list", params)
        when "get_company" then get_entity("crm.company.get", params)
        when "create_company" then create_entity("crm.company.add", params)
        when "update_company" then update_entity("crm.company.update", params)
        when "list_leads" then list_entities("crm.lead.list", params)
        when "get_lead" then get_entity("crm.lead.get", params)
        when "create_lead" then create_entity("crm.lead.add", params)
        when "update_lead" then update_entity("crm.lead.update", params)
        else raise Connectors::ActionNotFoundError, "Unknown action: #{action}"
        end
      end

      private

      def test_connection
        data = api_call("profile", {})
        { success: true, status: "connected", user: data["result"] }
      rescue Connectors::AuthenticationError
        raise
      rescue Connectors::Error => e
        raise Connectors::AuthenticationError, "Bitrix24 connection test failed: #{e.message}"
      end

      def list_entities(method, params)
        body = {}
        body[:start] = params[:start] if params[:start].present?
        body[:filter] = params[:filter] if params[:filter].present?
        body[:select] = params[:select] if params[:select].present?

        data = api_call(method, body)
        {
          items: data["result"] || [],
          total: data["total"] || 0,
          next: data["next"]
        }
      end

      def get_entity(method, params)
        id = params[:id]
        raise Connectors::Error, "id is required" if id.blank?

        data = api_call(method, { id: id })
        { item: data["result"] || {} }
      end

      def create_entity(method, params)
        fields = params[:fields]
        raise Connectors::Error, "fields is required" if fields.blank?

        data = api_call(method, { fields: fields })
        { id: data["result"], success: true }
      end

      def update_entity(method, params)
        id = params[:id]
        fields = params[:fields]
        raise Connectors::Error, "id is required" if id.blank?
        raise Connectors::Error, "fields is required" if fields.blank?

        data = api_call(method, { id: id, fields: fields })
        { success: data["result"] == true || data["result"].present? }
      end

      def api_call(method, params)
        response = client.post("#{base_url}#{method}", params)
        handle_response(response)
      end

      def base_url
        domain = credentials[:domain].to_s.strip
        token = credentials[:webhook_token].to_s.strip
        raise Connectors::AuthenticationError, "Bitrix24 domain is required" if domain.blank?
        raise Connectors::AuthenticationError, "Bitrix24 webhook token is required" if token.blank?

        "https://#{domain}/rest/#{token}/"
      end

      def client
        @client ||= Faraday.new do |f|
          f.request :json
          f.response :json
          f.options.timeout = 30
        end
      end

      def handle_response(response)
        unless response.success?
          error_message = response.body.is_a?(Hash) ? response.body.dig("error_description") || response.body["error"] : nil
          if response.status == 401
            hint = error_message&.include?("scope") ? " (webhook may be missing required scope)" : " (check webhook permissions)"
            raise Connectors::AuthenticationError, "Bitrix24 authorization failed#{hint}: #{error_message || 'HTTP 401'}"
          end
          raise Connectors::Error, "Bitrix24 API error (HTTP #{response.status}): #{error_message || 'Unknown error'}"
        end

        body = response.body
        if body.is_a?(Hash) && body["error"].present?
          error_code = body["error"]
          error_desc = body["error_description"] || error_code
          if error_code == "NO_AUTH_FOUND" || error_code == "INVALID_TOKEN"
            raise Connectors::AuthenticationError, "Authentication failed: #{error_desc}"
          end
          if error_code == "insufficient_scope" || error_code == "ACCESS_DENIED"
            raise Connectors::AuthenticationError, "Missing scope: #{error_desc}. Update your Bitrix24 webhook to include the required permissions (e.g. crm)."
          end
          raise Connectors::Error, "Bitrix24 API error: #{error_desc}"
        end

        body
      rescue Faraday::Error => e
        raise Connectors::Error, "Bitrix24 API request failed: #{e.message}"
      end
    end
  end
end
