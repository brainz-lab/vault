# frozen_string_literal: true

module Connectors
  module Native
    class Discord < Base
      def self.piece_name = "discord"
      def self.display_name = "Discord"
      def self.description = "Send messages and manage channels via Discord Bot or Webhooks"
      def self.category = "communication"
      def self.logo_url = "https://cdn.brainzlab.ai/connectors/discord.svg"
      def self.auth_type = "CUSTOM_AUTH"
      def self.auth_schema
        {
          type: "CUSTOM_AUTH",
          props: {
            bot_token: { type: "string", description: "Discord Bot Token (Developer Portal → Bot)", required: false },
            webhook_url: { type: "string", description: "Discord Webhook URL (Channel Settings → Integrations)", required: false },
            default_channel_id: { type: "string", description: "Default channel ID for bot messages", required: false }
          }
        }
      end

      def self.setup_guide
        {
          steps: [
            "Option A (Bot): Go to https://discord.com/developers/applications",
            "Create an application → Bot → Copy the bot token",
            "Invite the bot to your server with Send Messages permission",
            "Option B (Webhook): Go to Channel Settings → Integrations → Webhooks",
            "Create a webhook and copy the URL"
          ],
          docs_url: "https://discord.com/developers/docs/intro"
        }
      end

      def self.actions
        [
          {
            "name" => "send_message",
            "displayName" => "Send Message",
            "description" => "Send a message to a Discord channel (via Bot)",
            "props" => {
              "channel_id" => { "type" => "string", "required" => false, "description" => "Channel ID (uses default if omitted)" },
              "content" => { "type" => "string", "required" => true, "description" => "Message content (up to 2000 chars)" },
              "tts" => { "type" => "boolean", "required" => false, "description" => "Text-to-speech (default: false)" }
            }
          },
          {
            "name" => "send_embed",
            "displayName" => "Send Embed",
            "description" => "Send a rich embed message (via Bot)",
            "props" => {
              "channel_id" => { "type" => "string", "required" => false, "description" => "Channel ID (uses default if omitted)" },
              "title" => { "type" => "string", "required" => true, "description" => "Embed title" },
              "description" => { "type" => "string", "required" => false, "description" => "Embed description" },
              "color" => { "type" => "number", "required" => false, "description" => "Embed color (decimal, e.g., 5814783 for blue)" },
              "url" => { "type" => "string", "required" => false, "description" => "Embed URL" },
              "fields" => { "type" => "json", "required" => false, "description" => "Array of { name, value, inline } objects" }
            }
          },
          {
            "name" => "send_webhook",
            "displayName" => "Send Webhook",
            "description" => "Send a message via Discord Webhook (no bot needed)",
            "props" => {
              "content" => { "type" => "string", "required" => true, "description" => "Message content" },
              "username" => { "type" => "string", "required" => false, "description" => "Override webhook username" },
              "avatar_url" => { "type" => "string", "required" => false, "description" => "Override webhook avatar URL" },
              "embeds" => { "type" => "json", "required" => false, "description" => "Array of embed objects" }
            }
          },
          {
            "name" => "list_channels",
            "displayName" => "List Channels",
            "description" => "List channels in a server (via Bot)",
            "props" => {
              "guild_id" => { "type" => "string", "required" => true, "description" => "Server (guild) ID" }
            }
          },
          {
            "name" => "get_messages",
            "displayName" => "Get Messages",
            "description" => "Get recent messages from a channel (via Bot)",
            "props" => {
              "channel_id" => { "type" => "string", "required" => true, "description" => "Channel ID" },
              "limit" => { "type" => "number", "required" => false, "description" => "Max messages (1-100, default: 50)" }
            }
          },
          {
            "name" => "create_thread",
            "displayName" => "Create Thread",
            "description" => "Create a new thread in a channel (via Bot)",
            "props" => {
              "channel_id" => { "type" => "string", "required" => true, "description" => "Parent channel ID" },
              "name" => { "type" => "string", "required" => true, "description" => "Thread name" },
              "message" => { "type" => "string", "required" => false, "description" => "First message in the thread" },
              "auto_archive_duration" => { "type" => "number", "required" => false, "description" => "Auto-archive minutes: 60, 1440, 4320, 10080" }
            }
          }
        ]
      end

      API_BASE = "https://discord.com/api/v10"

      def execute(action, **params)
        case action.to_s
        when "send_message" then send_message(params)
        when "send_embed" then send_embed(params)
        when "send_webhook" then send_webhook(params)
        when "list_channels" then list_channels(params)
        when "get_messages" then get_messages(params)
        when "create_thread" then create_thread(params)
        else raise Connectors::ActionNotFoundError, "Unknown Discord action: #{action}"
        end
      end

      private

      def send_message(params)
        require_bot!
        channel = params[:channel_id] || default_channel_id
        raise Connectors::Error, "channel_id is required" unless channel.present?

        body = { content: params[:content] }
        body[:tts] = params[:tts] if params[:tts]

        result = bot_post("channels/#{channel}/messages", body)
        { success: true, id: result["id"], channel_id: result["channel_id"] }
      end

      def send_embed(params)
        require_bot!
        channel = params[:channel_id] || default_channel_id
        raise Connectors::Error, "channel_id is required" unless channel.present?

        embed = { title: params[:title] }
        embed[:description] = params[:description] if params[:description].present?
        embed[:color] = params[:color].to_i if params[:color].present?
        embed[:url] = params[:url] if params[:url].present?
        embed[:fields] = parse_json(params[:fields]) if params[:fields].present?

        result = bot_post("channels/#{channel}/messages", { embeds: [embed] })
        { success: true, id: result["id"], channel_id: result["channel_id"] }
      end

      def send_webhook(params)
        url = credentials[:webhook_url]
        raise Connectors::Error, "No webhook_url configured" unless url.present?

        body = { content: params[:content] }
        body[:username] = params[:username] if params[:username].present?
        body[:avatar_url] = params[:avatar_url] if params[:avatar_url].present?
        body[:embeds] = parse_json(params[:embeds]) if params[:embeds].present?

        resp = faraday.post(url) do |req|
          req.headers["Content-Type"] = "application/json"
          req.body = body.to_json
        end

        unless resp.success?
          raise Connectors::Error, "Discord webhook failed: HTTP #{resp.status}"
        end

        { success: true }
      end

      def list_channels(params)
        require_bot!
        result = bot_get("guilds/#{params[:guild_id]}/channels")
        channels = result.select { |c| [0, 2, 5, 15].include?(c["type"]) }.map do |c|
          type_name = { 0 => "text", 2 => "voice", 5 => "announcement", 15 => "forum" }[c["type"]]
          { id: c["id"], name: c["name"], type: type_name, position: c["position"], topic: c["topic"] }
        end
        { channels: channels, count: channels.size }
      end

      def get_messages(params)
        require_bot!
        limit = [(params[:limit] || 50).to_i, 100].min
        result = bot_get("channels/#{params[:channel_id]}/messages", limit: limit)
        messages = result.map do |m|
          { id: m["id"], content: m["content"], author: m.dig("author", "username"),
            timestamp: m["timestamp"], type: m["type"] }
        end
        { messages: messages, count: messages.size }
      end

      def create_thread(params)
        require_bot!
        body = { name: params[:name], type: 11 }
        body[:auto_archive_duration] = params[:auto_archive_duration] if params[:auto_archive_duration].present?

        if params[:message].present?
          body[:message] = { content: params[:message] }
          result = bot_post("channels/#{params[:channel_id]}/threads", body)
        else
          result = bot_post("channels/#{params[:channel_id]}/threads", body)
        end

        { success: true, id: result["id"], name: result["name"] }
      end

      def bot_post(path, body)
        resp = faraday.post("#{API_BASE}/#{path}") do |req|
          req.headers["Authorization"] = "Bot #{bot_token}"
          req.headers["Content-Type"] = "application/json"
          req.body = body.to_json
        end
        handle_response(resp)
      end

      def bot_get(path, params = {})
        resp = faraday.get("#{API_BASE}/#{path}") do |req|
          req.headers["Authorization"] = "Bot #{bot_token}"
          req.params = params
        end
        handle_response(resp)
      end

      def handle_response(resp)
        return {} if resp.body.blank?
        data = JSON.parse(resp.body)

        if data.is_a?(Hash) && !resp.success?
          error = data["message"] || "HTTP #{resp.status}"
          raise Connectors::AuthenticationError, "Discord: #{error}" if resp.status == 401 || resp.status == 403
          raise Connectors::RateLimitError, "Discord rate limited (retry after #{data['retry_after']}s)" if resp.status == 429
          raise Connectors::Error, "Discord API error: #{error}"
        end

        data
      end

      def require_bot!
        raise Connectors::AuthenticationError, "Discord bot_token is required for this action" unless bot_token.present?
      end

      def bot_token = credentials[:bot_token]
      def default_channel_id = credentials[:default_channel_id]

      def parse_json(value)
        return value if value.is_a?(Array) || value.is_a?(Hash)
        JSON.parse(value) rescue value
      end

      def faraday
        @faraday ||= Faraday.new { |f| f.options.timeout = 15; f.options.open_timeout = 5 }
      end
    end
  end
end
