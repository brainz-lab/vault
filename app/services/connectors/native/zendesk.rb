# frozen_string_literal: true

module Connectors
  module Native
    class Zendesk < Base
      def self.piece_name = "zendesk"
      def self.display_name = "Zendesk"
      def self.description = "Manage tickets, users, and organizations in Zendesk Support"
      def self.category = "support"
      def self.logo_url = "https://cdn.brainzlab.ai/connectors/zendesk.svg"
      def self.auth_type = "CUSTOM_AUTH"
      def self.auth_schema
        {
          type: "CUSTOM_AUTH",
          props: {
            subdomain: { type: "string", description: "Zendesk subdomain (e.g., 'mycompany' for mycompany.zendesk.com)", required: true },
            email: { type: "string", description: "Agent email address", required: true },
            api_token: { type: "string", description: "API token (Settings → API → Add API Token)", required: true }
          }
        }
      end

      def self.setup_guide
        {
          steps: [
            "Go to your Zendesk Admin Center → Apps & Integrations → APIs → Zendesk API",
            "Enable Token Access if not already enabled",
            "Click 'Add API Token' and copy the generated token",
            "Enter your subdomain (the part before .zendesk.com)",
            "Enter the email of an agent with appropriate permissions"
          ],
          docs_url: "https://developer.zendesk.com/api-reference/introduction/security-and-auth/"
        }
      end

      def self.actions
        [
          {
            "name" => "list_tickets",
            "displayName" => "List Tickets",
            "description" => "List recent tickets",
            "props" => {
              "status" => { "type" => "string", "required" => false, "description" => "Filter: new, open, pending, hold, solved, closed" },
              "sort_by" => { "type" => "string", "required" => false, "description" => "Sort: created_at, updated_at, priority, status (default: created_at)" },
              "sort_order" => { "type" => "string", "required" => false, "description" => "Order: asc or desc (default: desc)" },
              "limit" => { "type" => "number", "required" => false, "description" => "Max tickets (default: 25)" }
            }
          },
          {
            "name" => "get_ticket",
            "displayName" => "Get Ticket",
            "description" => "Get a single ticket by ID",
            "props" => {
              "ticket_id" => { "type" => "string", "required" => true, "description" => "Ticket ID" }
            }
          },
          {
            "name" => "create_ticket",
            "displayName" => "Create Ticket",
            "description" => "Create a new support ticket",
            "props" => {
              "subject" => { "type" => "string", "required" => true, "description" => "Ticket subject" },
              "body" => { "type" => "string", "required" => true, "description" => "Ticket description/first comment" },
              "priority" => { "type" => "string", "required" => false, "description" => "Priority: urgent, high, normal, low (default: normal)" },
              "type" => { "type" => "string", "required" => false, "description" => "Type: problem, incident, question, task" },
              "requester_email" => { "type" => "string", "required" => false, "description" => "Requester email (creates user if needed)" },
              "requester_name" => { "type" => "string", "required" => false, "description" => "Requester name" },
              "assignee_email" => { "type" => "string", "required" => false, "description" => "Assignee email" },
              "tags" => { "type" => "string", "required" => false, "description" => "Comma-separated tags" }
            }
          },
          {
            "name" => "update_ticket",
            "displayName" => "Update Ticket",
            "description" => "Update an existing ticket",
            "props" => {
              "ticket_id" => { "type" => "string", "required" => true, "description" => "Ticket ID" },
              "status" => { "type" => "string", "required" => false, "description" => "New status: open, pending, hold, solved, closed" },
              "priority" => { "type" => "string", "required" => false, "description" => "New priority: urgent, high, normal, low" },
              "comment" => { "type" => "string", "required" => false, "description" => "Add a comment to the ticket" },
              "public_comment" => { "type" => "boolean", "required" => false, "description" => "Is the comment public? (default: true)" },
              "assignee_email" => { "type" => "string", "required" => false, "description" => "New assignee email" },
              "tags" => { "type" => "string", "required" => false, "description" => "Replace tags (comma-separated)" }
            }
          },
          {
            "name" => "list_users",
            "displayName" => "List Users",
            "description" => "List users (agents, admins, end-users)",
            "props" => {
              "role" => { "type" => "string", "required" => false, "description" => "Filter: end-user, agent, admin" },
              "limit" => { "type" => "number", "required" => false, "description" => "Max users (default: 25)" }
            }
          },
          {
            "name" => "search",
            "displayName" => "Search",
            "description" => "Search tickets, users, or organizations",
            "props" => {
              "query" => { "type" => "string", "required" => true, "description" => "Search query (Zendesk search syntax)" },
              "type" => { "type" => "string", "required" => false, "description" => "Limit to: ticket, user, organization" },
              "limit" => { "type" => "number", "required" => false, "description" => "Max results (default: 25)" }
            }
          },
          {
            "name" => "add_comment",
            "displayName" => "Add Comment",
            "description" => "Add a comment to a ticket",
            "props" => {
              "ticket_id" => { "type" => "string", "required" => true, "description" => "Ticket ID" },
              "body" => { "type" => "string", "required" => true, "description" => "Comment body" },
              "public" => { "type" => "boolean", "required" => false, "description" => "Public comment (default: true)" }
            }
          }
        ]
      end

      def execute(action, **params)
        case action.to_s
        when "list_tickets" then list_tickets(params)
        when "get_ticket" then get_ticket(params)
        when "create_ticket" then create_ticket(params)
        when "update_ticket" then update_ticket(params)
        when "list_users" then list_users(params)
        when "search" then search(params)
        when "add_comment" then add_comment(params)
        else raise Connectors::ActionNotFoundError, "Unknown Zendesk action: #{action}"
        end
      end

      private

      def list_tickets(params)
        query = {}
        query[:sort_by] = params[:sort_by] || "created_at"
        query[:sort_order] = params[:sort_order] || "desc"

        path = if params[:status].present?
                 "search.json?query=type:ticket status:#{params[:status]}&sort_by=#{query[:sort_by]}&sort_order=#{query[:sort_order]}"
               else
                 "tickets.json?sort_by=#{query[:sort_by]}&sort_order=#{query[:sort_order]}"
               end

        result = api_get(path)
        tickets = (result["tickets"] || result["results"] || []).first((params[:limit] || 25).to_i)
        tickets = tickets.map { |t| format_ticket(t) }
        { tickets: tickets, count: tickets.size }
      end

      def get_ticket(params)
        result = api_get("tickets/#{params[:ticket_id]}.json")
        format_ticket(result["ticket"])
      end

      def create_ticket(params)
        ticket = {
          subject: params[:subject],
          comment: { body: params[:body] }
        }
        ticket[:priority] = params[:priority] if params[:priority].present?
        ticket[:type] = params[:type] if params[:type].present?
        ticket[:tags] = params[:tags].split(",").map(&:strip) if params[:tags].present?

        if params[:requester_email].present?
          requester = { email: params[:requester_email] }
          requester[:name] = params[:requester_name] if params[:requester_name].present?
          ticket[:requester] = requester
        end

        ticket[:assignee_email] = params[:assignee_email] if params[:assignee_email].present?

        result = api_post("tickets.json", { ticket: ticket })
        t = result["ticket"]
        { success: true, id: t["id"], subject: t["subject"], status: t["status"], priority: t["priority"] }
      end

      def update_ticket(params)
        ticket = {}
        ticket[:status] = params[:status] if params[:status].present?
        ticket[:priority] = params[:priority] if params[:priority].present?
        ticket[:assignee_email] = params[:assignee_email] if params[:assignee_email].present?
        ticket[:tags] = params[:tags].split(",").map(&:strip) if params[:tags].present?

        if params[:comment].present?
          ticket[:comment] = {
            body: params[:comment],
            public: params[:public_comment] != false
          }
        end

        result = api_put("tickets/#{params[:ticket_id]}.json", { ticket: ticket })
        t = result["ticket"]
        { success: true, id: t["id"], subject: t["subject"], status: t["status"] }
      end

      def list_users(params)
        path = if params[:role].present?
                 "users.json?role=#{params[:role]}"
               else
                 "users.json"
               end

        result = api_get(path)
        users = (result["users"] || []).first((params[:limit] || 25).to_i)
        users = users.map do |u|
          { id: u["id"], name: u["name"], email: u["email"], role: u["role"], active: u["active"], created_at: u["created_at"] }
        end
        { users: users, count: users.size }
      end

      def search(params)
        query = params[:query]
        query = "type:#{params[:type]} #{query}" if params[:type].present?

        result = api_get("search.json", query: query)
        results = (result["results"] || []).first((params[:limit] || 25).to_i)
        results = results.map do |r|
          base = { id: r["id"], result_type: r["result_type"] }
          case r["result_type"]
          when "ticket"
            base.merge(subject: r["subject"], status: r["status"], priority: r["priority"])
          when "user"
            base.merge(name: r["name"], email: r["email"], role: r["role"])
          when "organization"
            base.merge(name: r["name"])
          else
            base
          end
        end
        { results: results, count: results.size, total: result["count"] }
      end

      def add_comment(params)
        ticket = {
          comment: {
            body: params[:body],
            public: params[:public] != false
          }
        }

        api_put("tickets/#{params[:ticket_id]}.json", { ticket: ticket })
        { success: true, ticket_id: params[:ticket_id] }
      end

      def api_get(path, params = {})
        resp = faraday.get("#{api_base}/#{path}") do |req|
          req.headers["Authorization"] = basic_auth_header
          req.headers["Content-Type"] = "application/json"
          req.params.merge!(params)
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
          error_detail = data["error"]
          error_msg = (error_detail.is_a?(Hash) ? error_detail["message"] : error_detail) || data["description"] || "HTTP #{resp.status}"
          raise Connectors::AuthenticationError, "Zendesk: #{error_msg}" if resp.status == 401
          raise Connectors::RateLimitError, "Zendesk rate limited" if resp.status == 429
          raise Connectors::Error, "Zendesk API error: #{error_msg}"
        end

        data
      end

      def format_ticket(t)
        {
          id: t["id"], subject: t["subject"], description: t["description"],
          status: t["status"], priority: t["priority"], type: t["type"],
          requester_id: t["requester_id"], assignee_id: t["assignee_id"],
          tags: t["tags"], created_at: t["created_at"], updated_at: t["updated_at"]
        }
      end

      def api_base
        "https://#{subdomain}.zendesk.com/api/v2"
      end

      def basic_auth_header
        "Basic #{Base64.strict_encode64("#{email}/token:#{api_token}")}"
      end

      def subdomain = credentials[:subdomain]
      def email = credentials[:email]
      def api_token = credentials[:api_token]

      def faraday
        @faraday ||= Faraday.new { |f| f.options.timeout = 20; f.options.open_timeout = 10 }
      end
    end
  end
end
