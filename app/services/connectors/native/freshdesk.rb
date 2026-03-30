# frozen_string_literal: true

module Connectors
  module Native
    class Freshdesk < Base
      def self.piece_name = "freshdesk"
      def self.display_name = "Freshdesk"
      def self.description = "Manage tickets, contacts, and companies in Freshdesk"
      def self.category = "support"
      def self.logo_url = "https://cdn.brainzlab.ai/connectors/freshdesk.svg"
      def self.auth_type = "CUSTOM_AUTH"
      def self.auth_schema
        {
          type: "CUSTOM_AUTH",
          props: {
            domain: { type: "string", description: "Freshdesk domain (e.g., mycompany for mycompany.freshdesk.com)", required: true },
            api_key: { type: "string", description: "API Key (Profile Settings → Your API Key)", required: true }
          }
        }
      end

      def self.setup_guide
        {
          steps: [
            "Log in to Freshdesk → click your profile picture → Profile Settings",
            "On the right side, find 'Your API Key' and copy it",
            "Enter your domain (the subdomain in your Freshdesk URL)"
          ],
          docs_url: "https://developers.freshdesk.com/api/"
        }
      end

      def self.actions
        [
          {
            "name" => "list_tickets",
            "displayName" => "List Tickets",
            "description" => "List recent tickets",
            "props" => {
              "filter" => { "type" => "string", "required" => false, "description" => "Filter: new_and_my_open, watching, spam, deleted (default: all)" },
              "order_by" => { "type" => "string", "required" => false, "description" => "Order by: created_at, due_by, updated_at (default: created_at)" },
              "order_type" => { "type" => "string", "required" => false, "description" => "Order: asc or desc (default: desc)" },
              "limit" => { "type" => "number", "required" => false, "description" => "Max tickets (default: 30)" }
            }
          },
          {
            "name" => "create_ticket",
            "displayName" => "Create Ticket",
            "description" => "Create a new support ticket",
            "props" => {
              "subject" => { "type" => "string", "required" => true, "description" => "Ticket subject" },
              "description" => { "type" => "string", "required" => true, "description" => "Ticket description (HTML supported)" },
              "email" => { "type" => "string", "required" => true, "description" => "Requester email" },
              "priority" => { "type" => "number", "required" => false, "description" => "Priority: 1=low, 2=medium, 3=high, 4=urgent (default: 1)" },
              "status" => { "type" => "number", "required" => false, "description" => "Status: 2=open, 3=pending, 4=resolved, 5=closed (default: 2)" },
              "type" => { "type" => "string", "required" => false, "description" => "Ticket type (e.g., Question, Incident, Problem)" },
              "tags" => { "type" => "string", "required" => false, "description" => "Comma-separated tags" }
            }
          },
          {
            "name" => "update_ticket",
            "displayName" => "Update Ticket",
            "description" => "Update an existing ticket",
            "props" => {
              "ticket_id" => { "type" => "number", "required" => true, "description" => "Ticket ID" },
              "status" => { "type" => "number", "required" => false, "description" => "New status: 2=open, 3=pending, 4=resolved, 5=closed" },
              "priority" => { "type" => "number", "required" => false, "description" => "New priority: 1=low, 2=medium, 3=high, 4=urgent" },
              "agent_id" => { "type" => "number", "required" => false, "description" => "Assign to agent ID" },
              "tags" => { "type" => "string", "required" => false, "description" => "Replace tags (comma-separated)" }
            }
          },
          {
            "name" => "reply_ticket",
            "displayName" => "Reply to Ticket",
            "description" => "Add a reply to a ticket",
            "props" => {
              "ticket_id" => { "type" => "number", "required" => true, "description" => "Ticket ID" },
              "body" => { "type" => "string", "required" => true, "description" => "Reply body (HTML supported)" }
            }
          },
          {
            "name" => "add_note",
            "displayName" => "Add Note",
            "description" => "Add a private or public note to a ticket",
            "props" => {
              "ticket_id" => { "type" => "number", "required" => true, "description" => "Ticket ID" },
              "body" => { "type" => "string", "required" => true, "description" => "Note body (HTML supported)" },
              "private" => { "type" => "boolean", "required" => false, "description" => "Private note (default: true)" }
            }
          },
          {
            "name" => "list_contacts",
            "displayName" => "List Contacts",
            "description" => "List contacts",
            "props" => {
              "email" => { "type" => "string", "required" => false, "description" => "Filter by email" },
              "phone" => { "type" => "string", "required" => false, "description" => "Filter by phone" },
              "limit" => { "type" => "number", "required" => false, "description" => "Max results (default: 30)" }
            }
          },
          {
            "name" => "create_contact",
            "displayName" => "Create Contact",
            "description" => "Create a new contact",
            "props" => {
              "name" => { "type" => "string", "required" => true, "description" => "Contact name" },
              "email" => { "type" => "string", "required" => true, "description" => "Email address" },
              "phone" => { "type" => "string", "required" => false, "description" => "Phone number" },
              "company_id" => { "type" => "number", "required" => false, "description" => "Company ID" }
            }
          }
        ]
      end

      def execute(action, **params)
        case action.to_s
        when "list_tickets" then list_tickets(params)
        when "create_ticket" then create_ticket(params)
        when "update_ticket" then update_ticket(params)
        when "reply_ticket" then reply_ticket(params)
        when "add_note" then add_note(params)
        when "list_contacts" then list_contacts(params)
        when "create_contact" then create_contact(params)
        else raise Connectors::ActionNotFoundError, "Unknown Freshdesk action: #{action}"
        end
      end

      private

      def list_tickets(params)
        query = { per_page: (params[:limit] || 30).to_i }
        query[:filter] = params[:filter] if params[:filter].present?
        query[:order_by] = params[:order_by] || "created_at"
        query[:order_type] = params[:order_type] || "desc"

        result = api_get("tickets", query)
        tickets = (result || []).map { |t| format_ticket(t) }
        { tickets: tickets, count: tickets.size }
      end

      def create_ticket(params)
        body = {
          subject: params[:subject],
          description: params[:description],
          email: params[:email],
          priority: (params[:priority] || 1).to_i,
          status: (params[:status] || 2).to_i
        }
        body[:type] = params[:type] if params[:type].present?
        body[:tags] = params[:tags].split(",").map(&:strip) if params[:tags].present?

        result = api_post("tickets", body)
        { success: true, id: result["id"], subject: result["subject"], status: result["status"] }
      end

      def update_ticket(params)
        body = {}
        body[:status] = params[:status].to_i if params[:status].present?
        body[:priority] = params[:priority].to_i if params[:priority].present?
        body[:responder_id] = params[:agent_id].to_i if params[:agent_id].present?
        body[:tags] = params[:tags].split(",").map(&:strip) if params[:tags].present?

        result = api_put("tickets/#{params[:ticket_id]}", body)
        { success: true, id: result["id"], status: result["status"] }
      end

      def reply_ticket(params)
        body = { body: params[:body] }
        result = api_post("tickets/#{params[:ticket_id]}/reply", body)
        { success: true, id: result["id"] }
      end

      def add_note(params)
        body = { body: params[:body], private: params[:private] != false }
        result = api_post("tickets/#{params[:ticket_id]}/notes", body)
        { success: true, id: result["id"] }
      end

      def list_contacts(params)
        query = { per_page: (params[:limit] || 30).to_i }
        query[:email] = params[:email] if params[:email].present?
        query[:phone] = params[:phone] if params[:phone].present?

        result = api_get("contacts", query)
        contacts = (result || []).map do |c|
          { id: c["id"], name: c["name"], email: c["email"], phone: c["phone"],
            company_id: c["company_id"], created_at: c["created_at"] }
        end
        { contacts: contacts, count: contacts.size }
      end

      def create_contact(params)
        body = { name: params[:name], email: params[:email] }
        body[:phone] = params[:phone] if params[:phone].present?
        body[:company_id] = params[:company_id] if params[:company_id].present?

        result = api_post("contacts", body)
        { success: true, id: result["id"], name: result["name"], email: result["email"] }
      end

      def format_ticket(t)
        { id: t["id"], subject: t["subject"], status: t["status"], priority: t["priority"],
          type: t["type"], requester_id: t["requester_id"], responder_id: t["responder_id"],
          tags: t["tags"], created_at: t["created_at"], updated_at: t["updated_at"] }
      end

      def api_get(path, params = {})
        resp = faraday.get("#{api_base}/#{path}") do |req|
          req.headers["Authorization"] = basic_auth_header
          req.headers["Content-Type"] = "application/json"
          req.params = params
        end
        handle_response(resp)
      end

      def api_post(path, body)
        resp = faraday.post("#{api_base}/#{path}") do |req|
          req.headers["Authorization"] = basic_auth_header
          req.headers["Content-Type"] = "application/json"
          req.body = body.to_json
        end
        handle_response(resp)
      end

      def api_put(path, body)
        resp = faraday.put("#{api_base}/#{path}") do |req|
          req.headers["Authorization"] = basic_auth_header
          req.headers["Content-Type"] = "application/json"
          req.body = body.to_json
        end
        handle_response(resp)
      end

      def handle_response(resp)
        data = JSON.parse(resp.body)
        unless resp.success?
          error = data.dig("errors", 0, "message") || data["description"] || data["message"] || "HTTP #{resp.status}"
          raise Connectors::AuthenticationError, "Freshdesk: #{error}" if resp.status == 401
          raise Connectors::RateLimitError, "Freshdesk rate limited" if resp.status == 429
          raise Connectors::Error, "Freshdesk API error: #{error}"
        end
        data
      end

      def api_base = "https://#{domain}.freshdesk.com/api/v2"
      def basic_auth_header = "Basic #{Base64.strict_encode64("#{api_key}:X")}"
      def domain = credentials[:domain]
      def api_key = credentials[:api_key]

      def faraday
        @faraday ||= Faraday.new { |f| f.options.timeout = 20; f.options.open_timeout = 10 }
      end
    end
  end
end
