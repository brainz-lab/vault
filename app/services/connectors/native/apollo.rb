module Connectors
  module Native
    class Apollo < Base
      def self.piece_name = "apollo"
      def self.display_name = "Apollo.io"
      def self.description = "B2B data enrichment and lead intelligence platform for sales prospecting"
      def self.category = "sales"
      def self.auth_type = "SECRET_TEXT"
      def self.auth_schema
        { type: "SECRET_TEXT", props: { api_key: { type: "string", description: "Apollo.io API key" } } }
      end

      def self.logo_url
        "/images/connectors/apollo.svg"
      end

      def self.setup_guide
        {
          title: "How to get your Apollo.io API Key",
          steps: [
            { title: "Sign in to Apollo", description: "Go to app.apollo.io and sign in to your account" },
            { title: "Open Settings", description: "Click on your profile icon in the bottom-left corner and select 'Settings'" },
            { title: "Navigate to API", description: "In the left sidebar, click on 'Integrations' then 'API Keys'" },
            { title: "Create API Key", description: "Click 'Create New Key', give it a name (e.g. 'Nexus Integration'), and copy the generated key" },
            { title: "Configure in Nexus", description: "Paste the API key in the field above and save" }
          ],
          tips: [
            "Apollo offers a free tier with limited credits — enough to test the integration",
            "The API key gives access to all endpoints. You can manage permissions per key in Apollo settings",
            "Credits are consumed per enrichment request. Monitor usage in Apollo dashboard"
          ],
          credential_help: {
            "api_key" => "Your Apollo API key starting with 'api_...' — found in Settings > Integrations > API Keys"
          }
        }
      end

      def self.actions
        [
          {
            "name" => "test_connection",
            "displayName" => "Test Connection",
            "description" => "Validate the Apollo.io API key",
            "props" => {}
          },
          {
            "name" => "search_people",
            "displayName" => "Search People",
            "description" => "Search for people matching criteria",
            "props" => {
              "page" => { "type" => "integer", "required" => false, "description" => "Page number" },
              "per_page" => { "type" => "integer", "required" => false, "description" => "Results per page" },
              "person_titles" => { "type" => "array", "required" => false, "description" => "Job titles to filter by" },
              "organization_industry_tag_ids" => { "type" => "array", "required" => false, "description" => "Industry tag IDs" },
              "organization_num_employees_ranges" => { "type" => "array", "required" => false, "description" => "Employee count ranges" },
              "person_locations" => { "type" => "array", "required" => false, "description" => "Person locations" },
              "organization_technologies" => { "type" => "array", "required" => false, "description" => "Technologies used by organization" },
              "q_keywords" => { "type" => "string", "required" => false, "description" => "Keywords to search for" }
            }
          },
          {
            "name" => "enrich_person",
            "displayName" => "Enrich Person",
            "description" => "Match and enrich person data",
            "props" => {
              "first_name" => { "type" => "string", "required" => false, "description" => "First name" },
              "last_name" => { "type" => "string", "required" => false, "description" => "Last name" },
              "organization_name" => { "type" => "string", "required" => false, "description" => "Organization name" },
              "domain" => { "type" => "string", "required" => false, "description" => "Company domain" },
              "linkedin_url" => { "type" => "string", "required" => false, "description" => "LinkedIn profile URL" }
            }
          },
          {
            "name" => "enrich_by_id",
            "displayName" => "Enrich by ID",
            "description" => "Enrich person by Apollo ID",
            "props" => {
              "apollo_id" => { "type" => "string", "required" => true, "description" => "Apollo person ID" }
            }
          },
          {
            "name" => "enrich_company",
            "displayName" => "Enrich Company",
            "description" => "Enrich company data by domain",
            "props" => {
              "domain" => { "type" => "string", "required" => true, "description" => "Company domain" }
            }
          },
          {
            "name" => "verify_email",
            "displayName" => "Verify Email",
            "description" => "Verify an email address",
            "props" => {
              "email" => { "type" => "string", "required" => true, "description" => "Email address to verify" }
            }
          }
        ]
      end

      def execute(action, **params)
        case action.to_s
        when "test_connection" then test_connection
        when "search_people" then search_people(params)
        when "enrich_person" then enrich_person(params)
        when "enrich_by_id" then enrich_by_id(params)
        when "enrich_company" then enrich_company(params)
        when "verify_email" then verify_email(params)
        else raise Connectors::ActionNotFoundError, "Unknown action: #{action}"
        end
      end

      private

      def test_connection
        response = client.post("https://api.apollo.io/v1/mixed_people/api_search") do |req|
          req.body = { page: 1, per_page: 1, person_titles: [ "CEO" ] }
        end

        unless response.success?
          raise Connectors::AuthenticationError, "Apollo API key is invalid (HTTP #{response.status})"
        end

        { success: true, status: "connected", api_version: "v1" }
      rescue Faraday::Error => e
        raise Connectors::Error, "Apollo connection test failed: #{e.message}"
      end

      def search_people(params)
        body = params.slice(:page, :per_page, :person_titles, :organization_industry_tag_ids,
                            :organization_num_employees_ranges, :person_locations,
                            :organization_technologies, :q_keywords).compact

        response = client.post("https://api.apollo.io/v1/mixed_people/api_search") do |req|
          req.body = body
        end

        handle_response(response) do |data|
          {
            people: data["people"] || [],
            total_entries: data["pagination"]&.dig("total_entries") || 0,
            pagination: data["pagination"] || {}
          }
        end
      end

      def enrich_person(params)
        body = params.slice(:first_name, :last_name, :organization_name, :domain, :linkedin_url).compact

        response = client.post("https://api.apollo.io/api/v1/people/match") do |req|
          req.body = body
        end

        handle_response(response) do |data|
          { person: data["person"] || {} }
        end
      end

      def enrich_by_id(params)
        apollo_id = params[:apollo_id]
        raise Connectors::Error, "apollo_id is required" if apollo_id.blank?

        response = client.get("https://api.apollo.io/api/v1/people/#{apollo_id}")

        handle_response(response) do |data|
          { person: data["person"] || {} }
        end
      end

      def enrich_company(params)
        domain = params[:domain]
        raise Connectors::Error, "domain is required" if domain.blank?

        response = client.get("https://api.apollo.io/api/v1/organizations/enrich") do |req|
          req.params["domain"] = domain
        end

        handle_response(response) do |data|
          { organization: data["organization"] || {} }
        end
      end

      def verify_email(params)
        email = params[:email]
        raise Connectors::Error, "email is required" if email.blank?

        response = client.post("https://api.apollo.io/v1/mixed_people/api_search") do |req|
          req.body = { page: 1, per_page: 1, q_keywords: email }
        end

        handle_response(response) do |data|
          person = data.dig("people", 0)
          {
            email: email,
            found: person.present?,
            person: person || {}
          }
        end
      end

      def client
        @client ||= Faraday.new do |f|
          f.request :json
          f.response :json
          f.options.timeout = 30
          f.headers["X-Api-Key"] = credentials[:api_key]
        end
      end

      def handle_response(response)
        unless response.success?
          error_message = response.body.is_a?(Hash) ? response.body["message"] || response.body["error"] : nil
          raise Connectors::Error, "Apollo API error (HTTP #{response.status}): #{error_message || 'Unknown error'}"
        end

        yield response.body
      rescue Faraday::Error => e
        raise Connectors::Error, "Apollo API request failed: #{e.message}"
      end
    end
  end
end
