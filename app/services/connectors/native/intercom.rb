# frozen_string_literal: true

module Connectors
  module Native
    class Intercom < Base
      def self.piece_name = "intercom"
      def self.display_name = "Intercom"
      def self.description = "Manage contacts, conversations, and messages in Intercom"
      def self.category = "support"
      def self.logo_url = "https://cdn.brainzlab.ai/connectors/intercom.svg"
      def self.auth_type = "SECRET_TEXT"
      def self.auth_schema
        {
          type: "SECRET_TEXT",
          props: {
            access_token: { type: "string", description: "Intercom Access Token (Settings → Integrations → Developer Hub)", required: true }
          }
        }
      end

      def self.setup_guide
        {
          steps: [
            "Go to Intercom → Settings → Integrations → Developer Hub",
            "Create a new app or select an existing one",
            "Go to Authentication and copy the Access Token",
            "Ensure the app has necessary permissions (read/write contacts, conversations)"
          ],
          docs_url: "https://developers.intercom.com/docs/build-an-integration/getting-started/"
        }
      end

      def self.actions
        [
          {
            "name" => "list_contacts",
            "displayName" => "List Contacts",
            "description" => "List contacts (users and leads)",
            "props" => {
              "limit" => { "type" => "number", "required" => false, "description" => "Max results (default: 50)" }
            }
          },
          {
            "name" => "search_contacts",
            "displayName" => "Search Contacts",
            "description" => "Search contacts by email or name",
            "props" => {
              "query" => { "type" => "string", "required" => true, "description" => "Email or name to search" },
              "field" => { "type" => "string", "required" => false, "description" => "Field: email, name (default: email)" }
            }
          },
          {
            "name" => "create_contact",
            "displayName" => "Create Contact",
            "description" => "Create a new user or lead",
            "props" => {
              "role" => { "type" => "string", "required" => true, "description" => "Role: user or lead" },
              "email" => { "type" => "string", "required" => true, "description" => "Email address" },
              "name" => { "type" => "string", "required" => false, "description" => "Full name" },
              "phone" => { "type" => "string", "required" => false, "description" => "Phone number" },
              "external_id" => { "type" => "string", "required" => false, "description" => "External user ID" }
            }
          },
          {
            "name" => "list_conversations",
            "displayName" => "List Conversations",
            "description" => "List recent conversations",
            "props" => {
              "limit" => { "type" => "number", "required" => false, "description" => "Max results (default: 20)" }
            }
          },
          {
            "name" => "get_conversation",
            "displayName" => "Get Conversation",
            "description" => "Get a conversation with its messages",
            "props" => {
              "conversation_id" => { "type" => "string", "required" => true, "description" => "Conversation ID" }
            }
          },
          {
            "name" => "reply_conversation",
            "displayName" => "Reply to Conversation",
            "description" => "Send a reply in a conversation",
            "props" => {
              "conversation_id" => { "type" => "string", "required" => true, "description" => "Conversation ID" },
              "body" => { "type" => "string", "required" => true, "description" => "Reply message (HTML supported)" },
              "admin_id" => { "type" => "string", "required" => true, "description" => "Admin ID sending the reply" },
              "message_type" => { "type" => "string", "required" => false, "description" => "Type: comment or note (default: comment)" }
            }
          },
          {
            "name" => "send_message",
            "displayName" => "Send Message",
            "description" => "Send a new outbound message to a contact",
            "props" => {
              "from_admin_id" => { "type" => "string", "required" => true, "description" => "Admin ID sending the message" },
              "to_contact_id" => { "type" => "string", "required" => true, "description" => "Contact ID to message" },
              "subject" => { "type" => "string", "required" => false, "description" => "Message subject (for email type)" },
              "body" => { "type" => "string", "required" => true, "description" => "Message body (HTML supported)" },
              "message_type" => { "type" => "string", "required" => false, "description" => "Type: inapp or email (default: inapp)" }
            }
          },
          {
            "name" => "tag_contact",
            "displayName" => "Tag Contact",
            "description" => "Add a tag to a contact",
            "props" => {
              "contact_id" => { "type" => "string", "required" => true, "description" => "Contact ID" },
              "tag_name" => { "type" => "string", "required" => true, "description" => "Tag name (creates if not exists)" }
            }
          }
        ]
      end

      API_BASE = "https://api.intercom.io"

      def execute(action, **params)
        case action.to_s
        when "list_contacts" then list_contacts(params)
        when "search_contacts" then search_contacts(params)
        when "create_contact" then create_contact(params)
        when "list_conversations" then list_conversations(params)
        when "get_conversation" then get_conversation(params)
        when "reply_conversation" then reply_conversation(params)
        when "send_message" then send_message(params)
        when "tag_contact" then tag_contact(params)
        else raise Connectors::ActionNotFoundError, "Unknown Intercom action: #{action}"
        end
      end

      private

      def list_contacts(params)
        result = api_get("contacts", per_page: (params[:limit] || 50).to_i)
        contacts = (result["data"] || []).map { |c| format_contact(c) }
        { contacts: contacts, count: contacts.size, total: result["total_count"] }
      end

      def search_contacts(params)
        field = params[:field] || "email"
        body = {
          query: { field: field, operator: "=", value: params[:query] }
        }
        result = api_post("contacts/search", body)
        contacts = (result["data"] || []).map { |c| format_contact(c) }
        { contacts: contacts, count: contacts.size }
      end

      def create_contact(params)
        body = { role: params[:role], email: params[:email] }
        body[:name] = params[:name] if params[:name].present?
        body[:phone] = params[:phone] if params[:phone].present?
        body[:external_id] = params[:external_id] if params[:external_id].present?

        result = api_post("contacts", body)
        { success: true, id: result["id"], email: result["email"], role: result["role"] }
      end

      def list_conversations(params)
        result = api_get("conversations", per_page: (params[:limit] || 20).to_i)
        conversations = (result["conversations"] || []).map do |c|
          { id: c["id"], state: c["state"], open: c["open"], read: c["read"],
            title: c.dig("source", "subject") || c.dig("source", "body")&.truncate(100),
            created_at: c["created_at"], updated_at: c["updated_at"] }
        end
        { conversations: conversations, count: conversations.size }
      end

      def get_conversation(params)
        result = api_get("conversations/#{params[:conversation_id]}")
        parts = (result.dig("conversation_parts", "conversation_parts") || []).map do |p|
          { id: p["id"], part_type: p["part_type"], body: p["body"]&.truncate(500),
            author_type: p.dig("author", "type"), created_at: p["created_at"] }
        end
        {
          id: result["id"], state: result["state"], title: result.dig("source", "subject"),
          source_body: result.dig("source", "body")&.truncate(500),
          parts: parts, parts_count: parts.size
        }
      end

      def reply_conversation(params)
        body = {
          message_type: params[:message_type] || "comment",
          type: "admin",
          admin_id: params[:admin_id],
          body: params[:body]
        }
        result = api_post("conversations/#{params[:conversation_id]}/reply", body)
        { success: true, conversation_id: result["conversation_id"] || params[:conversation_id] }
      end

      def send_message(params)
        body = {
          message_type: params[:message_type] || "inapp",
          body: params[:body],
          from: { type: "admin", id: params[:from_admin_id] },
          to: { type: "contact", id: params[:to_contact_id] }
        }
        body[:subject] = params[:subject] if params[:subject].present?

        result = api_post("messages", body)
        { success: true, message_type: result["message_type"], id: result["id"] }
      end

      def tag_contact(params)
        tag = find_or_create_tag(params[:tag_name])
        api_post("contacts/#{params[:contact_id]}/tags", { id: tag["id"] })
        { success: true, tag_name: params[:tag_name], contact_id: params[:contact_id] }
      end

      def find_or_create_tag(name)
        result = api_get("tags")
        existing = (result["data"] || []).find { |t| t["name"] == name }
        return existing if existing

        api_post("tags", { name: name })
      end

      def format_contact(c)
        { id: c["id"], external_id: c["external_id"], email: c["email"],
          name: c["name"], phone: c["phone"], role: c["role"],
          created_at: c["created_at"], updated_at: c["updated_at"] }
      end

      def api_get(path, params = {})
        resp = faraday.get("#{API_BASE}/#{path}") do |req|
          req.headers["Authorization"] = "Bearer #{access_token}"
          req.headers["Accept"] = "application/json"
          req.headers["Intercom-Version"] = "2.11"
          req.params = params
        end
        handle_response(resp)
      end

      def api_post(path, body)
        resp = faraday.post("#{API_BASE}/#{path}") do |req|
          req.headers["Authorization"] = "Bearer #{access_token}"
          req.headers["Content-Type"] = "application/json"
          req.headers["Accept"] = "application/json"
          req.headers["Intercom-Version"] = "2.11"
          req.body = body.to_json
        end
        handle_response(resp)
      end

      def handle_response(resp)
        data = JSON.parse(resp.body)
        unless resp.success?
          errors = data.dig("errors")&.map { |e| e["message"] }&.join(", ") || data["message"] || "HTTP #{resp.status}"
          raise Connectors::AuthenticationError, "Intercom: #{errors}" if resp.status == 401
          raise Connectors::RateLimitError, "Intercom rate limited" if resp.status == 429
          raise Connectors::Error, "Intercom API error: #{errors}"
        end
        data
      end

      def access_token = credentials[:access_token]

      def faraday
        @faraday ||= Faraday.new { |f| f.options.timeout = 20; f.options.open_timeout = 10 }
      end
    end
  end
end
