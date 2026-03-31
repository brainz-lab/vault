# frozen_string_literal: true

module Connectors
  module Native
    class Pipedrive < Base
      def self.piece_name = "pipedrive"
      def self.display_name = "Pipedrive"
      def self.description = "Manage deals, contacts, and activities in Pipedrive CRM"
      def self.category = "crm"
      def self.logo_url = "https://cdn.brainzlab.ai/connectors/pipedrive.svg"
      def self.auth_type = "SECRET_TEXT"
      def self.auth_schema
        {
          type: "SECRET_TEXT",
          props: {
            api_token: { type: "string", description: "Pipedrive API Token (Settings → Personal preferences → API)", required: true },
            company_domain: { type: "string", description: "Company domain (e.g., mycompany for mycompany.pipedrive.com)", required: true }
          }
        }
      end

      def self.setup_guide
        {
          steps: [
            "Log in to Pipedrive → Settings → Personal preferences → API",
            "Copy your personal API token",
            "Enter your company domain (the subdomain in your Pipedrive URL)"
          ],
          docs_url: "https://developers.pipedrive.com/docs/api/v1"
        }
      end

      def self.actions
        [
          {
            "name" => "list_deals",
            "displayName" => "List Deals",
            "description" => "List deals with optional filtering",
            "props" => {
              "status" => { "type" => "string", "required" => false, "description" => "Filter: open, won, lost, deleted (default: all_not_deleted)" },
              "sort" => { "type" => "string", "required" => false, "description" => "Sort field (e.g., add_time DESC)" },
              "limit" => { "type" => "number", "required" => false, "description" => "Max results (default: 50)" }
            }
          },
          {
            "name" => "create_deal",
            "displayName" => "Create Deal",
            "description" => "Create a new deal",
            "props" => {
              "title" => { "type" => "string", "required" => true, "description" => "Deal title" },
              "value" => { "type" => "number", "required" => false, "description" => "Deal value" },
              "currency" => { "type" => "string", "required" => false, "description" => "Currency code (e.g., USD)" },
              "person_id" => { "type" => "number", "required" => false, "description" => "Contact person ID" },
              "org_id" => { "type" => "number", "required" => false, "description" => "Organization ID" },
              "stage_id" => { "type" => "number", "required" => false, "description" => "Pipeline stage ID" }
            }
          },
          {
            "name" => "update_deal",
            "displayName" => "Update Deal",
            "description" => "Update an existing deal",
            "props" => {
              "deal_id" => { "type" => "number", "required" => true, "description" => "Deal ID" },
              "title" => { "type" => "string", "required" => false, "description" => "New title" },
              "value" => { "type" => "number", "required" => false, "description" => "New value" },
              "status" => { "type" => "string", "required" => false, "description" => "New status: open, won, lost" },
              "stage_id" => { "type" => "number", "required" => false, "description" => "New stage ID" }
            }
          },
          {
            "name" => "list_persons",
            "displayName" => "List Contacts",
            "description" => "List contact persons",
            "props" => {
              "term" => { "type" => "string", "required" => false, "description" => "Search term" },
              "limit" => { "type" => "number", "required" => false, "description" => "Max results (default: 50)" }
            }
          },
          {
            "name" => "create_person",
            "displayName" => "Create Contact",
            "description" => "Create a new contact person",
            "props" => {
              "name" => { "type" => "string", "required" => true, "description" => "Full name" },
              "email" => { "type" => "string", "required" => false, "description" => "Email address" },
              "phone" => { "type" => "string", "required" => false, "description" => "Phone number" },
              "org_id" => { "type" => "number", "required" => false, "description" => "Organization ID" }
            }
          },
          {
            "name" => "list_activities",
            "displayName" => "List Activities",
            "description" => "List scheduled activities",
            "props" => {
              "type" => { "type" => "string", "required" => false, "description" => "Activity type (call, meeting, task, etc.)" },
              "done" => { "type" => "boolean", "required" => false, "description" => "Filter by completion status" },
              "limit" => { "type" => "number", "required" => false, "description" => "Max results (default: 50)" }
            }
          },
          {
            "name" => "create_activity",
            "displayName" => "Create Activity",
            "description" => "Schedule a new activity",
            "props" => {
              "subject" => { "type" => "string", "required" => true, "description" => "Activity subject" },
              "type" => { "type" => "string", "required" => true, "description" => "Type: call, meeting, task, deadline, email, lunch" },
              "due_date" => { "type" => "string", "required" => false, "description" => "Due date (YYYY-MM-DD)" },
              "due_time" => { "type" => "string", "required" => false, "description" => "Due time (HH:MM)" },
              "deal_id" => { "type" => "number", "required" => false, "description" => "Associated deal ID" },
              "person_id" => { "type" => "number", "required" => false, "description" => "Associated person ID" },
              "note" => { "type" => "string", "required" => false, "description" => "Activity note" }
            }
          }
        ]
      end

      def execute(action, **params)
        case action.to_s
        when "list_deals" then list_deals(params)
        when "create_deal" then create_deal(params)
        when "update_deal" then update_deal(params)
        when "list_persons" then list_persons(params)
        when "create_person" then create_person(params)
        when "list_activities" then list_activities(params)
        when "create_activity" then create_activity(params)
        else raise Connectors::ActionNotFoundError, "Unknown Pipedrive action: #{action}"
        end
      end

      private

      def list_deals(params)
        query = { limit: (params[:limit] || 50).to_i }
        query[:status] = params[:status] if params[:status].present?
        query[:sort] = params[:sort] if params[:sort].present?

        result = api_get("deals", query)
        deals = (result["data"] || []).map do |d|
          { id: d["id"], title: d["title"], value: d["value"], currency: d["currency"],
            status: d["status"], stage_id: d["stage_id"], person_name: d.dig("person_id", "name"),
            org_name: d.dig("org_id", "name"), add_time: d["add_time"] }
        end
        { deals: deals, count: deals.size }
      end

      def create_deal(params)
        body = { title: params[:title] }
        body[:value] = params[:value] if params[:value].present?
        body[:currency] = params[:currency] if params[:currency].present?
        body[:person_id] = params[:person_id] if params[:person_id].present?
        body[:org_id] = params[:org_id] if params[:org_id].present?
        body[:stage_id] = params[:stage_id] if params[:stage_id].present?

        result = api_post("deals", body)
        d = result["data"]
        { success: true, id: d["id"], title: d["title"] }
      end

      def update_deal(params)
        body = {}
        body[:title] = params[:title] if params[:title].present?
        body[:value] = params[:value] if params[:value].present?
        body[:status] = params[:status] if params[:status].present?
        body[:stage_id] = params[:stage_id] if params[:stage_id].present?

        result = api_put("deals/#{params[:deal_id]}", body)
        d = result["data"]
        { success: true, id: d["id"], title: d["title"], status: d["status"] }
      end

      def list_persons(params)
        if params[:term].present?
          result = api_get("persons/search", { term: params[:term], limit: (params[:limit] || 50).to_i })
          persons = (result.dig("data", "items") || []).map do |item|
            p = item["item"]
            { id: p["id"], name: p["name"], emails: p["emails"], phones: p["phones"], org_name: p["organization"]&.dig("name") }
          end
        else
          result = api_get("persons", { limit: (params[:limit] || 50).to_i })
          persons = (result["data"] || []).map do |p|
            { id: p["id"], name: p["name"], email: p["email"]&.first&.dig("value"),
              phone: p["phone"]&.first&.dig("value"), org_name: p.dig("org_id", "name") }
          end
        end
        { persons: persons, count: persons.size }
      end

      def create_person(params)
        body = { name: params[:name] }
        body[:email] = [ { value: params[:email], primary: true, label: "work" } ] if params[:email].present?
        body[:phone] = [ { value: params[:phone], primary: true, label: "work" } ] if params[:phone].present?
        body[:org_id] = params[:org_id] if params[:org_id].present?

        result = api_post("persons", body)
        p = result["data"]
        { success: true, id: p["id"], name: p["name"] }
      end

      def list_activities(params)
        query = { limit: (params[:limit] || 50).to_i }
        query[:type] = params[:type] if params[:type].present?
        query[:done] = params[:done] ? 1 : 0 if params.key?(:done)

        result = api_get("activities", query)
        activities = (result["data"] || []).map do |a|
          { id: a["id"], subject: a["subject"], type: a["type"], done: a["done"],
            due_date: a["due_date"], due_time: a["due_time"], deal_id: a["deal_id"] }
        end
        { activities: activities, count: activities.size }
      end

      def create_activity(params)
        body = { subject: params[:subject], type: params[:type] }
        body[:due_date] = params[:due_date] if params[:due_date].present?
        body[:due_time] = params[:due_time] if params[:due_time].present?
        body[:deal_id] = params[:deal_id] if params[:deal_id].present?
        body[:person_id] = params[:person_id] if params[:person_id].present?
        body[:note] = params[:note] if params[:note].present?

        result = api_post("activities", body)
        a = result["data"]
        { success: true, id: a["id"], subject: a["subject"], type: a["type"] }
      end

      def api_get(path, params = {})
        resp = faraday.get("#{api_base}/#{path}") do |req|
          req.params = params.merge(api_token: api_token)
        end
        handle_response(resp)
      end

      def api_post(path, body)
        resp = faraday.post("#{api_base}/#{path}?api_token=#{api_token}") do |req|
          req.headers["Content-Type"] = "application/json"
          req.body = body.to_json
        end
        handle_response(resp)
      end

      def api_put(path, body)
        resp = faraday.put("#{api_base}/#{path}?api_token=#{api_token}") do |req|
          req.headers["Content-Type"] = "application/json"
          req.body = body.to_json
        end
        handle_response(resp)
      end

      def handle_response(resp)
        data = JSON.parse(resp.body)
        unless data["success"]
          error = data["error"] || "HTTP #{resp.status}"
          raise Connectors::AuthenticationError, "Pipedrive: #{error}" if resp.status == 401 || resp.status == 403
          raise Connectors::RateLimitError, "Pipedrive rate limited" if resp.status == 429
          raise Connectors::Error, "Pipedrive API error: #{error}"
        end
        data
      end

      def api_base = "https://#{company_domain}.pipedrive.com/api/v1"
      def api_token = credentials[:api_token]
      def company_domain = credentials[:company_domain]

      def faraday
        @faraday ||= Faraday.new { |f| f.options.timeout = 15; f.options.open_timeout = 5 }
      end
    end
  end
end
