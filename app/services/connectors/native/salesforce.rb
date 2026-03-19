module Connectors
  module Native
    class Salesforce < Base
      # Salesforce REST API v59.0

      def self.piece_name = "salesforce"
      def self.display_name = "Salesforce"
      def self.description = "CRM platform for contacts, leads, accounts, opportunities, and pipeline management"
      def self.category = "crm"
      def self.auth_type = "OAUTH2"

      def self.auth_schema
        {
          type: "OAUTH2",
          authUrl: "https://login.salesforce.com/services/oauth2/authorize",
          tokenUrl: "https://login.salesforce.com/services/oauth2/token",
          scope: "api refresh_token",
          pkce: true,
          props: {
            instance_url: { type: "string", required: true, description: "Your Salesforce instance URL, e.g. https://yourorg.my.salesforce.com" },
            client_id: { type: "string", required: true, description: "Connected App Consumer Key (Client ID)" },
            client_secret: { type: "string", required: true, description: "Connected App Consumer Secret" }
          },
          oauth: { requires_redirect: true }
        }
      end

      def self.logo_url
        "/images/connectors/salesforce.svg"
      end

      def self.setup_guide
        {
          title: "How to configure your Salesforce Connected App",
          steps: [
            { title: "Log in to Salesforce", description: "Go to your Salesforce org and sign in as an administrator." },
            { title: "Navigate to Setup", description: "Click the gear icon in the top right and select 'Setup'." },
            { title: "Create a Connected App", description: "In Setup, search for 'App Manager' in the Quick Find box. Click 'New Connected App'. Fill in the basic info (name, email)." },
            { title: "Enable OAuth Settings", description: "Check 'Enable OAuth Settings'. Set the Callback URL to: #{ENV.fetch('VAULT_URL', 'http://localhost:4006')}/oauth/callback/salesforce. Select OAuth scopes: 'Manage user data via APIs (api)' and 'Perform requests at any time (refresh_token, offline_access)'." },
            { title: "Save and get credentials", description: "After saving, wait a few minutes for the app to activate. Then go to 'Manage Consumer Details' to get the Consumer Key (Client ID) and Consumer Secret." },
            { title: "Enter credentials and authorize", description: "Enter your Instance URL, Client ID, and Client Secret below, then click 'Authorize with Salesforce' to connect your account." }
          ],
          tips: [
            "Your instance URL is the base URL when logged into Salesforce (e.g. https://yourorg.my.salesforce.com)",
            "Connected Apps may take up to 10 minutes to activate after creation",
            "For sandbox environments, use https://test.salesforce.com as the instance URL",
            "Make sure the Connected App has the 'api' and 'refresh_token' OAuth scopes",
            "The callback URL in Salesforce must match exactly: #{ENV.fetch('VAULT_URL', 'http://localhost:4006')}/oauth/callback/salesforce"
          ],
          credential_help: {
            "instance_url" => "Your Salesforce org URL, e.g. https://yourorg.my.salesforce.com",
            "client_id" => "The Consumer Key from your Connected App settings",
            "client_secret" => "The Consumer Secret from your Connected App settings"
          }
        }
      end

      def self.actions
        [
          { "name" => "test_connection", "displayName" => "Test Connection", "description" => "Validate credentials against the Salesforce API", "props" => {} },
          # Contacts
          { "name" => "list_contacts", "displayName" => "List Contacts", "description" => "Query contacts with optional filters",
            "props" => {
              "limit" => { "type" => "integer", "required" => false, "description" => "Maximum number of records to return (default 100)" },
              "offset" => { "type" => "integer", "required" => false, "description" => "Offset for pagination" },
              "where" => { "type" => "string", "required" => false, "description" => "SOQL WHERE clause (e.g. \"LastName = 'Smith'\")" },
              "fields" => { "type" => "string", "required" => false, "description" => "Comma-separated fields to query (default: Id,FirstName,LastName,Email,Phone,Title,Account.Name,MailingCity,MailingCountry,MailingState,OwnerId,LeadSource,Description)" }
            } },
          { "name" => "get_contact", "displayName" => "Get Contact", "description" => "Get a contact by ID",
            "props" => {
              "id" => { "type" => "string", "required" => true, "description" => "Salesforce Contact ID (18-char)" }
            } },
          { "name" => "create_contact", "displayName" => "Create Contact", "description" => "Create a new contact",
            "props" => {
              "fields" => { "type" => "object", "required" => true, "description" => "Contact fields (e.g. {\"FirstName\": \"John\", \"LastName\": \"Doe\", \"Email\": \"john@example.com\"})" }
            } },
          { "name" => "update_contact", "displayName" => "Update Contact", "description" => "Update an existing contact",
            "props" => {
              "id" => { "type" => "string", "required" => true, "description" => "Salesforce Contact ID" },
              "fields" => { "type" => "object", "required" => true, "description" => "Fields to update" }
            } },
          # Leads
          { "name" => "list_leads", "displayName" => "List Leads", "description" => "Query leads with optional filters",
            "props" => {
              "limit" => { "type" => "integer", "required" => false, "description" => "Maximum number of records to return (default 100)" },
              "offset" => { "type" => "integer", "required" => false, "description" => "Offset for pagination" },
              "where" => { "type" => "string", "required" => false, "description" => "SOQL WHERE clause" },
              "fields" => { "type" => "string", "required" => false, "description" => "Comma-separated fields to query (default: Id,FirstName,LastName,Email,Phone,Title,Company,City,Country,State,OwnerId,LeadSource,Status,Description)" }
            } },
          { "name" => "get_lead", "displayName" => "Get Lead", "description" => "Get a lead by ID",
            "props" => {
              "id" => { "type" => "string", "required" => true, "description" => "Salesforce Lead ID" }
            } },
          { "name" => "create_lead", "displayName" => "Create Lead", "description" => "Create a new lead",
            "props" => {
              "fields" => { "type" => "object", "required" => true, "description" => "Lead fields (e.g. {\"FirstName\": \"John\", \"LastName\": \"Doe\", \"Company\": \"Acme\"})" }
            } },
          { "name" => "update_lead", "displayName" => "Update Lead", "description" => "Update an existing lead",
            "props" => {
              "id" => { "type" => "string", "required" => true, "description" => "Salesforce Lead ID" },
              "fields" => { "type" => "object", "required" => true, "description" => "Fields to update" }
            } },
          # Accounts
          { "name" => "list_accounts", "displayName" => "List Accounts", "description" => "Query accounts with optional filters",
            "props" => {
              "limit" => { "type" => "integer", "required" => false, "description" => "Maximum number of records to return (default 100)" },
              "offset" => { "type" => "integer", "required" => false, "description" => "Offset for pagination" },
              "where" => { "type" => "string", "required" => false, "description" => "SOQL WHERE clause" },
              "fields" => { "type" => "string", "required" => false, "description" => "Comma-separated fields to query" }
            } },
          { "name" => "get_account", "displayName" => "Get Account", "description" => "Get an account by ID",
            "props" => {
              "id" => { "type" => "string", "required" => true, "description" => "Salesforce Account ID" }
            } },
          { "name" => "create_account", "displayName" => "Create Account", "description" => "Create a new account",
            "props" => {
              "fields" => { "type" => "object", "required" => true, "description" => "Account fields (e.g. {\"Name\": \"Acme Corp\", \"Website\": \"https://acme.com\"})" }
            } },
          { "name" => "update_account", "displayName" => "Update Account", "description" => "Update an existing account",
            "props" => {
              "id" => { "type" => "string", "required" => true, "description" => "Salesforce Account ID" },
              "fields" => { "type" => "object", "required" => true, "description" => "Fields to update" }
            } },
          # Opportunities
          { "name" => "list_opportunities", "displayName" => "List Opportunities", "description" => "Query opportunities with optional filters",
            "props" => {
              "limit" => { "type" => "integer", "required" => false, "description" => "Maximum number of records to return (default 100)" },
              "offset" => { "type" => "integer", "required" => false, "description" => "Offset for pagination" },
              "where" => { "type" => "string", "required" => false, "description" => "SOQL WHERE clause" },
              "fields" => { "type" => "string", "required" => false, "description" => "Comma-separated fields to query" }
            } },
          { "name" => "get_opportunity", "displayName" => "Get Opportunity", "description" => "Get an opportunity by ID",
            "props" => {
              "id" => { "type" => "string", "required" => true, "description" => "Salesforce Opportunity ID" }
            } },
          { "name" => "create_opportunity", "displayName" => "Create Opportunity", "description" => "Create a new opportunity",
            "props" => {
              "fields" => { "type" => "object", "required" => true, "description" => "Opportunity fields (e.g. {\"Name\": \"Deal\", \"StageName\": \"Prospecting\", \"CloseDate\": \"2026-04-01\"})" }
            } },
          { "name" => "update_opportunity", "displayName" => "Update Opportunity", "description" => "Update an existing opportunity",
            "props" => {
              "id" => { "type" => "string", "required" => true, "description" => "Salesforce Opportunity ID" },
              "fields" => { "type" => "object", "required" => true, "description" => "Fields to update" }
            } },
          # SOQL
          { "name" => "query", "displayName" => "SOQL Query", "description" => "Execute a raw SOQL query",
            "props" => {
              "soql" => { "type" => "string", "required" => true, "description" => "SOQL query string (e.g. \"SELECT Id, Name FROM Account LIMIT 10\")" }
            } }
        ]
      end

      def execute(action, **params)
        case action.to_s
        when "test_connection" then test_connection
        when "list_contacts" then list_records("Contact", params)
        when "get_contact" then get_record("Contact", params)
        when "create_contact" then create_record("Contact", params)
        when "update_contact" then update_record("Contact", params)
        when "list_leads" then list_records("Lead", params)
        when "get_lead" then get_record("Lead", params)
        when "create_lead" then create_record("Lead", params)
        when "update_lead" then update_record("Lead", params)
        when "list_accounts" then list_records("Account", params)
        when "get_account" then get_record("Account", params)
        when "create_account" then create_record("Account", params)
        when "update_account" then update_record("Account", params)
        when "list_opportunities" then list_records("Opportunity", params)
        when "get_opportunity" then get_record("Opportunity", params)
        when "create_opportunity" then create_record("Opportunity", params)
        when "update_opportunity" then update_record("Opportunity", params)
        when "query" then soql_query(params)
        else raise Connectors::ActionNotFoundError, "Unknown action: #{action}"
        end
      end

      private

      API_VERSION = "v59.0"

      DEFAULT_FIELDS = {
        "Contact" => "Id,FirstName,LastName,Email,Phone,Title,AccountId,Account.Name,MailingCity,MailingCountry,MailingState,Website,OwnerId,LeadSource,Description",
        "Lead" => "Id,FirstName,LastName,Email,Phone,Title,Company,City,Country,State,Website,OwnerId,LeadSource,Status,Description",
        "Account" => "Id,Name,Website,Industry,Phone,BillingCity,BillingCountry,BillingState,OwnerId,Description,NumberOfEmployees",
        "Opportunity" => "Id,Name,StageName,Amount,CloseDate,AccountId,OwnerId,Description,Probability"
      }.freeze

      def test_connection
        response = api_request(:get, "/limits")
        { success: true, status: "connected", instance_url: instance_url }
      rescue Connectors::AuthenticationError
        raise
      rescue Connectors::Error => e
        raise Connectors::AuthenticationError, "Salesforce connection test failed: #{e.message}"
      end

      def list_records(sobject, params)
        fields = params[:fields] || DEFAULT_FIELDS[sobject] || "Id,Name"
        limit = (params[:limit] || 100).to_i.clamp(1, 2000)
        offset = (params[:offset] || 0).to_i

        soql = "SELECT #{fields} FROM #{sobject}"
        soql += " WHERE #{params[:where]}" if params[:where].present?
        soql += " ORDER BY CreatedDate DESC"
        soql += " LIMIT #{limit}"
        soql += " OFFSET #{offset}" if offset > 0

        data = api_request(:get, "/query", q: soql)

        records = data["records"] || []
        {
          records: records,
          items: records,
          total: data["totalSize"] || records.size,
          next: data["nextRecordsUrl"].present? ? offset + limit : nil
        }
      end

      def get_record(sobject, params)
        id = params[:id]
        raise Connectors::Error, "id is required" if id.blank?

        data = api_request(:get, "/sobjects/#{sobject}/#{id}")
        { item: data, Id: data["Id"] }
      end

      def create_record(sobject, params)
        fields = params[:fields]
        raise Connectors::Error, "fields is required" if fields.blank?

        body = fields.is_a?(Hash) ? fields : fields
        data = api_request(:post, "/sobjects/#{sobject}", body)

        { id: data["id"], Id: data["id"], success: data["success"] != false }
      end

      def update_record(sobject, params)
        id = params[:id]
        fields = params[:fields]
        raise Connectors::Error, "id is required" if id.blank?
        raise Connectors::Error, "fields is required" if fields.blank?

        data = api_request(:patch, "/sobjects/#{sobject}/#{id}", fields)

        if data == :no_content
          { success: true, id: id, Id: id }
        else
          { success: true, id: id, Id: id, result: data }
        end
      end

      def soql_query(params)
        soql = params[:soql]
        raise Connectors::Error, "soql is required" if soql.blank?

        data = api_request(:get, "/query", q: soql)

        records = data["records"] || []
        { records: records, items: records, total: data["totalSize"] || records.size }
      end

      # --- Authentication (OAuth2 Authorization Code Flow) ---

      def authenticate!
        @access_token = credentials[:access_token]
        @instance_url = credentials[:instance_url].to_s.chomp("/")

        raise Connectors::AuthenticationError, "No access_token in credentials. Complete the OAuth authorization flow first." if @access_token.blank?
      end

      def refresh_access_token!
        refresh_token = credentials[:_refresh_token]
        raise Connectors::AuthenticationError, "No refresh token available. Re-authorize with Salesforce." if refresh_token.blank?

        login_url = credentials[:instance_url].to_s.include?("test.salesforce.com") ? "https://test.salesforce.com" : "https://login.salesforce.com"

        response = Faraday.post("#{login_url}/services/oauth2/token") do |req|
          req.headers["Content-Type"] = "application/x-www-form-urlencoded"
          req.body = URI.encode_www_form(
            grant_type: "refresh_token",
            client_id: credentials[:client_id],
            client_secret: credentials[:client_secret],
            refresh_token: refresh_token
          )
        end

        unless response.success?
          body = JSON.parse(response.body) rescue {}
          raise Connectors::AuthenticationError, "Salesforce token refresh failed: #{body['error_description'] || body['error'] || 'Unknown error'}"
        end

        body = JSON.parse(response.body)
        @access_token = body["access_token"]
        @instance_url = body["instance_url"] if body["instance_url"].present?

        # Persist new access_token in credential
        if credentials[:_credential_id].present?
          credential = ConnectorCredential.find_by(id: credentials[:_credential_id])
          if credential
            current_creds = credential.decrypt_credentials
            current_creds[:access_token] = @access_token
            current_creds[:instance_url] = @instance_url if body["instance_url"].present?
            credential.update_credentials(current_creds)
          end
        end

        @client = nil # Reset client with new token
        @access_token
      end

      # Wrapper that auto-retries on 401 using refresh_token
      def api_request(method, path, params_or_body = nil)
        authenticate!

        response = execute_request(method, path, params_or_body)

        # On 401, try refreshing the token once
        if response.status == 401
          refresh_access_token!
          response = execute_request(method, path, params_or_body)
        end

        return :no_content if response.status == 204

        handle_response(response)
      end

      def execute_request(method, path, params_or_body)
        url = "#{api_base_url}#{path}"
        case method
        when :get
          client.get(url, params_or_body || {})
        when :post
          client.post(url, (params_or_body || {}).to_json)
        when :patch
          client.patch(url, (params_or_body || {}).to_json)
        when :delete
          client.delete(url)
        end
      end

      def instance_url
        @instance_url || credentials[:instance_url].to_s.chomp("/")
      end

      def api_base_url
        "#{instance_url}/services/data/#{API_VERSION}"
      end

      def client
        @client ||= Faraday.new do |f|
          f.request :json
          f.response :json
          f.headers["Authorization"] = "Bearer #{@access_token}"
          f.headers["Content-Type"] = "application/json"
          f.options.timeout = 30
        end
      end

      def handle_response(response)
        unless response.success?
          body = response.body
          error_message = extract_error(body)

          case response.status
          when 401
            raise Connectors::AuthenticationError, "Salesforce authentication failed: #{error_message || 'Invalid or expired session'}"
          when 403
            raise Connectors::AuthenticationError, "Salesforce access denied: #{error_message || 'Insufficient permissions'}"
          when 429
            raise Connectors::Error, "Salesforce API rate limit exceeded. Please retry after a short delay."
          end

          raise Connectors::Error, "Salesforce API error (HTTP #{response.status}): #{error_message || 'Unknown error'}"
        end

        body = response.body
        body.is_a?(Hash) ? body : (body.is_a?(Array) ? body.first : {})
      rescue Faraday::Error => e
        raise Connectors::Error, "Salesforce API request failed: #{e.message}"
      end

      def extract_error(body)
        if body.is_a?(Array) && body.first.is_a?(Hash)
          body.first["message"] || body.first["errorCode"]
        elsif body.is_a?(Hash)
          body["message"] || body["error_description"] || body["error"]
        end
      end
    end
  end
end
