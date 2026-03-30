# frozen_string_literal: true

module Connectors
  module Native
    class Telegram < Base
      def self.piece_name = "telegram"
      def self.display_name = "Telegram"
      def self.description = "Send messages, photos, and documents via Telegram Bot API"
      def self.category = "communication"
      def self.logo_url = "https://cdn.brainzlab.ai/connectors/telegram.svg"
      def self.auth_type = "SECRET_TEXT"
      def self.auth_schema
        {
          type: "SECRET_TEXT",
          props: {
            bot_token: { type: "string", description: "Telegram Bot Token (from @BotFather)", required: true },
            default_chat_id: { type: "string", description: "Default Chat ID for sending messages", required: false }
          }
        }
      end

      def self.setup_guide
        {
          steps: [
            "Open Telegram and search for @BotFather",
            "Send /newbot and follow the instructions to create a bot",
            "Copy the Bot Token provided by BotFather",
            "Add the bot to your group/channel or start a private chat",
            "Get the chat ID using the get_updates action or via @userinfobot"
          ],
          docs_url: "https://core.telegram.org/bots/tutorial"
        }
      end

      def self.actions
        [
          {
            "name" => "send_message",
            "displayName" => "Send Message",
            "description" => "Send a text message to a chat",
            "props" => {
              "chat_id" => { "type" => "string", "required" => false, "description" => "Chat ID or @channel_username (uses default if omitted)" },
              "text" => { "type" => "string", "required" => true, "description" => "Message text (supports Markdown or HTML)" },
              "parse_mode" => { "type" => "string", "required" => false, "description" => "Format: Markdown, MarkdownV2, or HTML (default: none)" },
              "disable_notification" => { "type" => "boolean", "required" => false, "description" => "Send silently (default: false)" },
              "reply_to_message_id" => { "type" => "number", "required" => false, "description" => "Message ID to reply to" }
            }
          },
          {
            "name" => "send_photo",
            "displayName" => "Send Photo",
            "description" => "Send a photo to a chat",
            "props" => {
              "chat_id" => { "type" => "string", "required" => false, "description" => "Chat ID (uses default if omitted)" },
              "photo" => { "type" => "string", "required" => true, "description" => "Photo URL or file_id" },
              "caption" => { "type" => "string", "required" => false, "description" => "Photo caption" },
              "parse_mode" => { "type" => "string", "required" => false, "description" => "Caption format: Markdown, MarkdownV2, or HTML" }
            }
          },
          {
            "name" => "send_document",
            "displayName" => "Send Document",
            "description" => "Send a document/file to a chat",
            "props" => {
              "chat_id" => { "type" => "string", "required" => false, "description" => "Chat ID (uses default if omitted)" },
              "document" => { "type" => "string", "required" => true, "description" => "Document URL or file_id" },
              "caption" => { "type" => "string", "required" => false, "description" => "Document caption" }
            }
          },
          {
            "name" => "get_updates",
            "displayName" => "Get Updates",
            "description" => "Get recent messages/updates received by the bot",
            "props" => {
              "limit" => { "type" => "number", "required" => false, "description" => "Max updates to return (1-100, default: 10)" },
              "offset" => { "type" => "number", "required" => false, "description" => "Offset for pagination" }
            }
          },
          {
            "name" => "set_webhook",
            "displayName" => "Set Webhook",
            "description" => "Set a webhook URL for receiving updates",
            "props" => {
              "url" => { "type" => "string", "required" => true, "description" => "HTTPS URL to receive updates" },
              "secret_token" => { "type" => "string", "required" => false, "description" => "Secret token for webhook verification" },
              "allowed_updates" => { "type" => "json", "required" => false, "description" => "Array of update types to receive (e.g., [\"message\", \"callback_query\"])" }
            }
          },
          {
            "name" => "get_chat",
            "displayName" => "Get Chat Info",
            "description" => "Get information about a chat",
            "props" => {
              "chat_id" => { "type" => "string", "required" => true, "description" => "Chat ID or @channel_username" }
            }
          }
        ]
      end

      def execute(action, **params)
        case action.to_s
        when "send_message" then send_message(params)
        when "send_photo" then send_photo(params)
        when "send_document" then send_document(params)
        when "get_updates" then get_updates(params)
        when "set_webhook" then set_webhook(params)
        when "get_chat" then get_chat(params)
        else raise Connectors::ActionNotFoundError, "Unknown Telegram action: #{action}"
        end
      end

      private

      def send_message(params)
        body = { chat_id: resolve_chat_id(params), text: params[:text] }
        body[:parse_mode] = params[:parse_mode] if params[:parse_mode].present?
        body[:disable_notification] = params[:disable_notification] if params.key?(:disable_notification)
        body[:reply_to_message_id] = params[:reply_to_message_id] if params[:reply_to_message_id].present?

        result = api_post("sendMessage", body)
        msg = result["result"]
        { success: true, message_id: msg["message_id"], chat_id: msg["chat"]["id"], date: msg["date"] }
      end

      def send_photo(params)
        body = { chat_id: resolve_chat_id(params), photo: params[:photo] }
        body[:caption] = params[:caption] if params[:caption].present?
        body[:parse_mode] = params[:parse_mode] if params[:parse_mode].present?

        result = api_post("sendPhoto", body)
        msg = result["result"]
        { success: true, message_id: msg["message_id"], chat_id: msg["chat"]["id"] }
      end

      def send_document(params)
        body = { chat_id: resolve_chat_id(params), document: params[:document] }
        body[:caption] = params[:caption] if params[:caption].present?

        result = api_post("sendDocument", body)
        msg = result["result"]
        { success: true, message_id: msg["message_id"], chat_id: msg["chat"]["id"] }
      end

      def get_updates(params)
        body = {}
        body[:limit] = [params[:limit].to_i, 100].min if params[:limit].present?
        body[:offset] = params[:offset].to_i if params[:offset].present?

        result = api_post("getUpdates", body)
        updates = (result["result"] || []).map do |u|
          msg = u["message"] || u["edited_message"] || u["channel_post"] || {}
          {
            update_id: u["update_id"],
            message_id: msg["message_id"],
            chat_id: msg.dig("chat", "id"),
            chat_type: msg.dig("chat", "type"),
            from: msg.dig("from", "username"),
            text: msg["text"],
            date: msg["date"]
          }
        end
        { updates: updates, count: updates.size }
      end

      def set_webhook(params)
        body = { url: params[:url] }
        body[:secret_token] = params[:secret_token] if params[:secret_token].present?

        allowed = params[:allowed_updates]
        if allowed.present?
          allowed = JSON.parse(allowed) if allowed.is_a?(String)
          body[:allowed_updates] = allowed
        end

        result = api_post("setWebhook", body)
        { success: true, description: result["description"] }
      end

      def get_chat(params)
        result = api_post("getChat", { chat_id: params[:chat_id] })
        chat = result["result"]
        { id: chat["id"], type: chat["type"], title: chat["title"], username: chat["username"], description: chat["description"] }
      end

      def api_post(method, body)
        resp = faraday.post("#{api_base}/#{method}") do |req|
          req.headers["Content-Type"] = "application/json"
          req.body = body.to_json
        end

        data = JSON.parse(resp.body)

        unless data["ok"]
          error_code = data["error_code"]
          description = data["description"] || "Unknown error"
          raise Connectors::AuthenticationError, "Telegram: #{description}" if error_code == 401
          raise Connectors::RateLimitError, "Telegram: #{description}" if error_code == 429
          raise Connectors::Error, "Telegram API error (#{error_code}): #{description}"
        end

        data
      end

      def api_base
        "https://api.telegram.org/bot#{bot_token}"
      end

      def resolve_chat_id(params)
        chat_id = params[:chat_id] || default_chat_id
        raise Connectors::Error, "chat_id is required (provide it or set a default_chat_id)" unless chat_id.present?
        chat_id
      end

      def bot_token = credentials[:bot_token]
      def default_chat_id = credentials[:default_chat_id]

      def faraday
        @faraday ||= Faraday.new { |f| f.options.timeout = 15; f.options.open_timeout = 5 }
      end
    end
  end
end
