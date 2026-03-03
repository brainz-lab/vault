module Connectors
  module Native
    class Kommo < Base
      # Kommo API rate limit: 7 requests/second per integration

      def self.piece_name = "kommo"
      def self.display_name = "Kommo"
      def self.description = "CRM platform for contacts, leads, companies, and pipeline management (formerly amoCRM)"
      def self.category = "crm"
      def self.auth_type = "CUSTOM_AUTH"

      def self.auth_schema
        {
          type: "CUSTOM_AUTH",
          props: {
            subdomain: { type: "string", required: true, description: "Your Kommo subdomain, e.g. mycompany from mycompany.kommo.com" },
            api_token: { type: "string", required: true, description: "Long-lived API token from your private integration" }
          }
        }
      end

      def self.logo_url
        "/images/connectors/kommo.svg"
      end

      def self.setup_guide
        {
          title: "How to configure your Kommo private integration",
          steps: [
            { title: "Log in to your Kommo account", description: "Go to your Kommo account at https://yoursubdomain.kommo.com and sign in as an administrator." },
            { title: "Navigate to Settings", description: "Click the gear icon or go to Settings in the left sidebar menu." },
            { title: "Open Integrations", description: "Under Settings, find and click 'Integrations' to manage your connected apps." },
            { title: "Create a private integration", description: "Click 'Create integration' or the '+' button. Choose 'Private integration'. Give it a name (e.g. 'BrainzLab') and grant the required permissions: contacts, leads, companies, tasks, and notifications." },
            { title: "Copy your credentials", description: "After creating the integration, you will see your long-lived API token. Copy the token and your subdomain (the part before .kommo.com in your URL) and paste them in the fields above." }
          ],
          tips: [
            "Your subdomain is the part before .kommo.com in your Kommo URL (e.g. 'mycompany' from mycompany.kommo.com)",
            "Private integration tokens do not expire unless revoked manually",
            "Make sure to grant all required permissions (contacts, leads, companies, tasks) when creating the integration",
            "If you previously used amoCRM, your subdomain may still use the .amocrm.com domain — use just the subdomain part",
            "You can create multiple private integrations with different permission scopes"
          ],
          credential_help: {
            "subdomain" => "Your Kommo subdomain, e.g. 'mycompany' from mycompany.kommo.com",
            "api_token" => "The long-lived API token from your private integration settings"
          }
        }
      end

      def self.actions
        [
          { "name" => "test_connection", "displayName" => "Test Connection", "description" => "Validate credentials against the Kommo API", "props" => {} },
          # Contacts
          { "name" => "list_contacts", "displayName" => "List Contacts", "description" => "List contacts with optional filters",
            "props" => {
              "page" => { "type" => "integer", "required" => false, "description" => "Page number for pagination" },
              "limit" => { "type" => "integer", "required" => false, "description" => "Number of results per page (max 250)" },
              "query" => { "type" => "string", "required" => false, "description" => "Search query string" },
              "with" => { "type" => "string", "required" => false, "description" => "Comma-separated related entities to include (e.g. leads,customers)" }
            } },
          { "name" => "get_contact", "displayName" => "Get Contact", "description" => "Get a contact by ID",
            "props" => {
              "id" => { "type" => "integer", "required" => true, "description" => "Contact ID" },
              "with" => { "type" => "string", "required" => false, "description" => "Comma-separated related entities to include" }
            } },
          { "name" => "create_contact", "displayName" => "Create Contact", "description" => "Create one or more contacts",
            "props" => {
              "fields" => { "type" => "array", "required" => true, "description" => "Array of contact objects with name, custom_fields_values, etc." }
            } },
          { "name" => "update_contact", "displayName" => "Update Contact", "description" => "Update one or more contacts",
            "props" => {
              "fields" => { "type" => "array", "required" => true, "description" => "Array of contact objects with id and fields to update" }
            } },
          # Leads
          { "name" => "list_leads", "displayName" => "List Leads", "description" => "List leads with optional filters",
            "props" => {
              "page" => { "type" => "integer", "required" => false, "description" => "Page number for pagination" },
              "limit" => { "type" => "integer", "required" => false, "description" => "Number of results per page (max 250)" },
              "query" => { "type" => "string", "required" => false, "description" => "Search query string" },
              "with" => { "type" => "string", "required" => false, "description" => "Comma-separated related entities to include" },
              "filter" => { "type" => "object", "required" => false, "description" => "Filter criteria (e.g. {\"statuses\": [{\"pipeline_id\": 1, \"status_id\": 142}]})" }
            } },
          { "name" => "get_lead", "displayName" => "Get Lead", "description" => "Get a lead by ID",
            "props" => {
              "id" => { "type" => "integer", "required" => true, "description" => "Lead ID" },
              "with" => { "type" => "string", "required" => false, "description" => "Comma-separated related entities to include" }
            } },
          { "name" => "create_lead", "displayName" => "Create Lead", "description" => "Create one or more leads",
            "props" => {
              "fields" => { "type" => "array", "required" => true, "description" => "Array of lead objects with name, price, status_id, pipeline_id, etc." }
            } },
          { "name" => "update_lead", "displayName" => "Update Lead", "description" => "Update one or more leads",
            "props" => {
              "fields" => { "type" => "array", "required" => true, "description" => "Array of lead objects with id and fields to update" }
            } },
          # Companies
          { "name" => "list_companies", "displayName" => "List Companies", "description" => "List companies with optional filters",
            "props" => {
              "page" => { "type" => "integer", "required" => false, "description" => "Page number for pagination" },
              "limit" => { "type" => "integer", "required" => false, "description" => "Number of results per page (max 250)" },
              "query" => { "type" => "string", "required" => false, "description" => "Search query string" }
            } },
          { "name" => "get_company", "displayName" => "Get Company", "description" => "Get a company by ID",
            "props" => {
              "id" => { "type" => "integer", "required" => true, "description" => "Company ID" }
            } },
          { "name" => "create_company", "displayName" => "Create Company", "description" => "Create one or more companies",
            "props" => {
              "fields" => { "type" => "array", "required" => true, "description" => "Array of company objects with name, custom_fields_values, etc." }
            } },
          { "name" => "update_company", "displayName" => "Update Company", "description" => "Update one or more companies",
            "props" => {
              "fields" => { "type" => "array", "required" => true, "description" => "Array of company objects with id and fields to update" }
            } },
          # Pipelines
          { "name" => "list_pipelines", "displayName" => "List Pipelines", "description" => "List all lead pipelines and their statuses",
            "props" => {} },
          # Tasks
          { "name" => "list_tasks", "displayName" => "List Tasks", "description" => "List tasks with optional filters",
            "props" => {
              "page" => { "type" => "integer", "required" => false, "description" => "Page number for pagination" },
              "limit" => { "type" => "integer", "required" => false, "description" => "Number of results per page (max 250)" },
              "filter" => { "type" => "object", "required" => false, "description" => "Filter criteria (e.g. {\"responsible_user_id\": 123})" }
            } },
          { "name" => "create_task", "displayName" => "Create Task", "description" => "Create one or more tasks",
            "props" => {
              "fields" => { "type" => "array", "required" => true, "description" => "Array of task objects with text, complete_till, entity_id, entity_type, etc." }
            } },
          # Notes
          { "name" => "list_notes", "displayName" => "List Notes", "description" => "List notes for a specific entity",
            "props" => {
              "entity_type" => { "type" => "string", "required" => true, "description" => "Entity type: leads, contacts, or companies" },
              "entity_id" => { "type" => "integer", "required" => true, "description" => "Entity ID" },
              "page" => { "type" => "integer", "required" => false, "description" => "Page number for pagination" },
              "limit" => { "type" => "integer", "required" => false, "description" => "Number of results per page (max 250)" }
            } },
          { "name" => "create_note", "displayName" => "Create Note", "description" => "Create one or more notes for a specific entity",
            "props" => {
              "entity_type" => { "type" => "string", "required" => true, "description" => "Entity type: leads, contacts, or companies" },
              "entity_id" => { "type" => "integer", "required" => true, "description" => "Entity ID" },
              "fields" => { "type" => "array", "required" => true, "description" => "Array of note objects with note_type and params" }
            } }
        ]
      end

      def execute(action, **params)
        case action.to_s
        when "test_connection" then test_connection
        when "list_contacts" then list_entities("contacts", params)
        when "get_contact" then get_entity("contacts", params)
        when "create_contact" then create_entities("contacts", params)
        when "update_contact" then update_entities("contacts", params)
        when "list_leads" then list_entities("leads", params)
        when "get_lead" then get_entity("leads", params)
        when "create_lead" then create_entities("leads", params)
        when "update_lead" then update_entities("leads", params)
        when "list_companies" then list_entities("companies", params)
        when "get_company" then get_entity("companies", params)
        when "create_company" then create_entities("companies", params)
        when "update_company" then update_entities("companies", params)
        when "list_pipelines" then list_pipelines
        when "list_tasks" then list_entities("tasks", params)
        when "create_task" then create_entities("tasks", params)
        when "list_notes" then list_notes(params)
        when "create_note" then create_notes(params)
        else raise Connectors::ActionNotFoundError, "Unknown action: #{action}"
        end
      end

      private

      def test_connection
        response = client.get("#{base_url}/account")
        data = handle_response(response)
        { success: true, status: "connected", account: data }
      rescue Connectors::AuthenticationError
        raise
      rescue Connectors::Error => e
        raise Connectors::AuthenticationError, "Kommo connection test failed: #{e.message}"
      end

      def list_entities(entity_type, params)
        query = {}
        query[:page] = params[:page] if params[:page].present?
        query[:limit] = params[:limit] if params[:limit].present?
        query[:query] = params[:query] if params[:query].present?
        query[:with] = params[:with] if params[:with].present?

        if params[:filter].present?
          params[:filter].each { |k, v| query[:"filter[#{k}]"] = v }
        end

        response = client.get("#{base_url}/#{entity_type}", query)
        data = handle_response(response)

        items = data.dig("_embedded", entity_type) || []
        {
          items: items,
          total: data["_total_items"] || items.size,
          next: next_page(data)
        }
      end

      def get_entity(entity_type, params)
        id = params[:id]
        raise Connectors::Error, "id is required" if id.blank?

        query = {}
        query[:with] = params[:with] if params[:with].present?

        response = client.get("#{base_url}/#{entity_type}/#{id}", query)
        data = handle_response(response)
        { item: data }
      end

      def create_entities(entity_type, params)
        fields = params[:fields]
        raise Connectors::Error, "fields is required" if fields.blank?

        body = fields.is_a?(Array) ? fields : [ fields ]
        response = client.post("#{base_url}/#{entity_type}", body)
        data = handle_response(response)

        created = data.dig("_embedded", entity_type) || []
        if created.size == 1
          { id: created.first["id"], success: true }
        else
          { ids: created.map { |e| e["id"] }, success: true }
        end
      end

      def update_entities(entity_type, params)
        fields = params[:fields]
        raise Connectors::Error, "fields is required" if fields.blank?

        body = fields.is_a?(Array) ? fields : [ fields ]
        response = client.patch("#{base_url}/#{entity_type}", body)
        handle_response(response)
        { success: true }
      end

      def list_pipelines
        response = client.get("#{base_url}/leads/pipelines")
        data = handle_response(response)

        pipelines = data.dig("_embedded", "pipelines") || []
        { items: pipelines, total: pipelines.size, next: nil }
      end

      def list_notes(params)
        entity_type = params[:entity_type]
        entity_id = params[:entity_id]
        raise Connectors::Error, "entity_type is required" if entity_type.blank?
        raise Connectors::Error, "entity_id is required" if entity_id.blank?

        query = {}
        query[:page] = params[:page] if params[:page].present?
        query[:limit] = params[:limit] if params[:limit].present?

        response = client.get("#{base_url}/#{entity_type}/#{entity_id}/notes", query)
        data = handle_response(response)

        notes = data.dig("_embedded", "notes") || []
        { items: notes, total: data["_total_items"] || notes.size, next: next_page(data) }
      end

      def create_notes(params)
        entity_type = params[:entity_type]
        entity_id = params[:entity_id]
        fields = params[:fields]
        raise Connectors::Error, "entity_type is required" if entity_type.blank?
        raise Connectors::Error, "entity_id is required" if entity_id.blank?
        raise Connectors::Error, "fields is required" if fields.blank?

        body = fields.is_a?(Array) ? fields : [ fields ]
        response = client.post("#{base_url}/#{entity_type}/#{entity_id}/notes", body)
        data = handle_response(response)

        created = data.dig("_embedded", "notes") || []
        if created.size == 1
          { id: created.first["id"], success: true }
        else
          { ids: created.map { |e| e["id"] }, success: true }
        end
      end

      def next_page(data)
        next_link = data.dig("_links", "next", "href")
        return nil unless next_link

        match = next_link.match(/page=(\d+)/)
        match ? match[1].to_i : nil
      end

      def base_url
        subdomain = credentials[:subdomain].to_s.strip
        raise Connectors::AuthenticationError, "Kommo subdomain is required" if subdomain.blank?
        raise Connectors::AuthenticationError, "Kommo API token is required" if credentials[:api_token].blank?

        subdomain = subdomain.sub(/\.kommo\.com\z/i, "").sub(/\.amocrm\.com\z/i, "")
        "https://#{subdomain}.kommo.com/api/v4"
      end

      def client
        token = credentials[:api_token].to_s.strip

        @client ||= Faraday.new do |f|
          f.request :json
          f.response :json
          f.headers["Authorization"] = "Bearer #{token}"
          f.options.timeout = 30
        end
      end

      def handle_response(response)
        unless response.success?
          body = response.body
          error_message = extract_error(body)

          case response.status
          when 401
            raise Connectors::AuthenticationError, "Kommo authentication failed: #{error_message || 'Invalid or expired API token'}"
          when 403
            raise Connectors::AuthenticationError, "Kommo access denied: #{error_message || 'Insufficient permissions'}"
          when 429
            raise Connectors::Error, "Kommo rate limit exceeded (max 7 req/sec). Please retry after a short delay."
          end

          raise Connectors::Error, "Kommo API error (HTTP #{response.status}): #{error_message || 'Unknown error'}"
        end

        response.body || {}
      rescue Faraday::Error => e
        raise Connectors::Error, "Kommo API request failed: #{e.message}"
      end

      def extract_error(body)
        return nil unless body.is_a?(Hash)

        body["detail"] || body["title"] || body.dig("validation-errors", 0, "detail") || body["error"]
      end
    end
  end
end
