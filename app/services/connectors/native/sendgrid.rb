# frozen_string_literal: true

module Connectors
  module Native
    class Sendgrid < Base
      def self.piece_name = "sendgrid"
      def self.display_name = "SendGrid"
      def self.description = "Send transactional and marketing emails via SendGrid"
      def self.category = "communication"
      def self.logo_url = "https://cdn.brainzlab.ai/connectors/sendgrid.svg"
      def self.auth_type = "SECRET_TEXT"
      def self.auth_schema
        {
          type: "SECRET_TEXT",
          props: {
            api_key: { type: "string", description: "SendGrid API Key (starts with SG...)", required: true },
            from_email: { type: "string", description: "Default sender email address", required: false },
            from_name: { type: "string", description: "Default sender name", required: false }
          }
        }
      end

      def self.setup_guide
        {
          steps: [
            "Sign up at https://signup.sendgrid.com/",
            "Go to Settings → API Keys → Create API Key",
            "Select 'Full Access' or 'Restricted Access' with Mail Send permission",
            "Copy the API key (it starts with SG.)",
            "Verify a sender email under Settings → Sender Authentication"
          ],
          docs_url: "https://docs.sendgrid.com/for-developers/sending-email/quickstart"
        }
      end

      def self.actions
        [
          {
            "name" => "send_email",
            "displayName" => "Send Email",
            "description" => "Send a plain text or HTML email",
            "props" => {
              "to" => { "type" => "string", "required" => true, "description" => "Recipient email address" },
              "subject" => { "type" => "string", "required" => true, "description" => "Email subject line" },
              "body" => { "type" => "string", "required" => true, "description" => "Email body (plain text)" },
              "html" => { "type" => "string", "required" => false, "description" => "HTML body (overrides plain text)" },
              "from_email" => { "type" => "string", "required" => false, "description" => "Sender email (overrides default)" },
              "from_name" => { "type" => "string", "required" => false, "description" => "Sender name (overrides default)" },
              "reply_to" => { "type" => "string", "required" => false, "description" => "Reply-to email address" },
              "cc" => { "type" => "string", "required" => false, "description" => "CC email address" },
              "bcc" => { "type" => "string", "required" => false, "description" => "BCC email address" }
            }
          },
          {
            "name" => "send_template_email",
            "displayName" => "Send Template Email",
            "description" => "Send an email using a dynamic template",
            "props" => {
              "to" => { "type" => "string", "required" => true, "description" => "Recipient email address" },
              "template_id" => { "type" => "string", "required" => true, "description" => "Dynamic template ID (starts with d-)" },
              "dynamic_data" => { "type" => "json", "required" => false, "description" => "Template substitution data (JSON object)" },
              "from_email" => { "type" => "string", "required" => false, "description" => "Sender email (overrides default)" },
              "from_name" => { "type" => "string", "required" => false, "description" => "Sender name (overrides default)" }
            }
          },
          {
            "name" => "list_contacts",
            "displayName" => "List Contacts",
            "description" => "Search or list marketing contacts",
            "props" => {
              "query" => { "type" => "string", "required" => false, "description" => "SGQL query (e.g., email LIKE '%@example.com')" },
              "limit" => { "type" => "number", "required" => false, "description" => "Max contacts to return (default: 50)" }
            }
          },
          {
            "name" => "add_contact",
            "displayName" => "Add/Update Contact",
            "description" => "Add or update a marketing contact",
            "props" => {
              "email" => { "type" => "string", "required" => true, "description" => "Contact email address" },
              "first_name" => { "type" => "string", "required" => false, "description" => "First name" },
              "last_name" => { "type" => "string", "required" => false, "description" => "Last name" },
              "list_ids" => { "type" => "json", "required" => false, "description" => "Array of list IDs to add contact to" },
              "custom_fields" => { "type" => "json", "required" => false, "description" => "Custom field values (JSON object)" }
            }
          },
          {
            "name" => "list_lists",
            "displayName" => "List Contact Lists",
            "description" => "Get all marketing contact lists",
            "props" => {
              "limit" => { "type" => "number", "required" => false, "description" => "Max lists to return (default: 50)" }
            }
          }
        ]
      end

      API_BASE = "https://api.sendgrid.com/v3"

      def execute(action, **params)
        case action.to_s
        when "send_email" then send_email(params)
        when "send_template_email" then send_template_email(params)
        when "list_contacts" then list_contacts(params)
        when "add_contact" then add_contact(params)
        when "list_lists" then list_lists(params)
        else raise Connectors::ActionNotFoundError, "Unknown SendGrid action: #{action}"
        end
      end

      private

      def send_email(params)
        from = {
          email: params[:from_email] || default_from_email,
          name: params[:from_name] || default_from_name
        }.compact

        raise Connectors::Error, "Sender email is required" unless from[:email].present?

        personalizations = [ { to: [ { email: params[:to] } ] } ]
        personalizations[0][:cc] = [ { email: params[:cc] } ] if params[:cc].present?
        personalizations[0][:bcc] = [ { email: params[:bcc] } ] if params[:bcc].present?

        body = {
          personalizations: personalizations,
          from: from,
          subject: params[:subject],
          content: []
        }

        body[:reply_to] = { email: params[:reply_to] } if params[:reply_to].present?

        if params[:html].present?
          body[:content] << { type: "text/html", value: params[:html] }
        else
          body[:content] << { type: "text/plain", value: params[:body] }
        end

        api_post("mail/send", body)
        { success: true, message: "Email sent to #{params[:to]}" }
      end

      def send_template_email(params)
        from = {
          email: params[:from_email] || default_from_email,
          name: params[:from_name] || default_from_name
        }.compact

        raise Connectors::Error, "Sender email is required" unless from[:email].present?

        dynamic_data = params[:dynamic_data]
        dynamic_data = JSON.parse(dynamic_data) if dynamic_data.is_a?(String)

        body = {
          personalizations: [ { to: [ { email: params[:to] } ], dynamic_template_data: dynamic_data || {} } ],
          from: from,
          template_id: params[:template_id]
        }

        api_post("mail/send", body)
        { success: true, message: "Template email sent to #{params[:to]}" }
      end

      def list_contacts(params)
        if params[:query].present?
          body = { query: params[:query] }
          result = api_post("marketing/contacts/search", body)
          contacts = (result["result"] || []).first((params[:limit] || 50).to_i)
        else
          result = api_get("marketing/contacts")
          contacts = (result["result"] || []).first((params[:limit] || 50).to_i)
        end

        contacts = contacts.map do |c|
          { id: c["id"], email: c["email"], first_name: c["first_name"], last_name: c["last_name"], created_at: c["created_at"] }
        end
        { contacts: contacts, count: contacts.size }
      end

      def add_contact(params)
        contact = { email: params[:email] }
        contact[:first_name] = params[:first_name] if params[:first_name].present?
        contact[:last_name] = params[:last_name] if params[:last_name].present?
        contact[:custom_fields] = parse_json(params[:custom_fields]) if params[:custom_fields].present?

        body = { contacts: [ contact ] }

        list_ids = parse_json(params[:list_ids])
        body[:list_ids] = list_ids if list_ids.is_a?(Array) && list_ids.any?

        result = api_put("marketing/contacts", body)
        { success: true, job_id: result["job_id"] }
      end

      def list_lists(params)
        limit = (params[:limit] || 50).to_i
        result = api_get("marketing/lists", page_size: limit)
        lists = (result["result"] || []).map do |l|
          { id: l["id"], name: l["name"], contact_count: l["contact_count"] }
        end
        { lists: lists, count: lists.size }
      end

      def api_post(path, body)
        resp = faraday.post("#{API_BASE}/#{path}") do |req|
          req.headers["Authorization"] = "Bearer #{api_key}"
          req.headers["Content-Type"] = "application/json"
          req.body = body.to_json
        end

        # mail/send returns 202 with empty body on success
        return {} if resp.status == 202

        handle_response(resp)
      end

      def api_put(path, body)
        resp = faraday.put("#{API_BASE}/#{path}") do |req|
          req.headers["Authorization"] = "Bearer #{api_key}"
          req.headers["Content-Type"] = "application/json"
          req.body = body.to_json
        end

        handle_response(resp)
      end

      def api_get(path, params = {})
        resp = faraday.get("#{API_BASE}/#{path}") do |req|
          req.headers["Authorization"] = "Bearer #{api_key}"
          req.params = params
        end

        handle_response(resp)
      end

      def handle_response(resp)
        return {} if resp.body.blank?

        data = JSON.parse(resp.body)

        unless resp.success?
          errors = data["errors"]&.map { |e| e["message"] }&.join(", ") || "HTTP #{resp.status}"
          raise Connectors::AuthenticationError, "SendGrid: #{errors}" if resp.status == 401 || resp.status == 403
          raise Connectors::RateLimitError, "SendGrid rate limited" if resp.status == 429
          raise Connectors::Error, "SendGrid API error: #{errors}"
        end

        data
      end

      def api_key = credentials[:api_key]
      def default_from_email = credentials[:from_email]
      def default_from_name = credentials[:from_name]

      def parse_json(value)
        return value if value.is_a?(Array) || value.is_a?(Hash)
        JSON.parse(value) rescue value
      end

      def faraday
        @faraday ||= Faraday.new { |f| f.options.timeout = 30; f.options.open_timeout = 10 }
      end
    end
  end
end
