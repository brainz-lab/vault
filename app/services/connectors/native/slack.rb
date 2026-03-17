# frozen_string_literal: true

module Connectors
  module Native
    class Slack < Base
      def self.piece_name = "slack"
      def self.display_name = "Slack"
      def self.description = "Send messages and notifications to Slack channels"
      def self.category = "communication"
      def self.logo_url = "https://cdn.brainzlab.ai/connectors/slack.svg"
      def self.auth_type = "CUSTOM_AUTH"
      def self.auth_schema
        {
          type: "CUSTOM_AUTH",
          props: {
            token: { type: "string", description: "Bot User OAuth Token (xoxb-...)", required: false },
            webhook_url: { type: "string", description: "Incoming Webhook URL", required: false },
            default_channel: { type: "string", description: "Default channel (e.g., #general)", required: false }
          }
        }
      end

      def self.setup_guide
        {
          steps: [
            "Go to https://api.slack.com/apps and create a new app",
            "Under 'OAuth & Permissions', add scopes: chat:write, channels:read, files:write, reactions:write",
            "Install the app to your workspace",
            "Copy the 'Bot User OAuth Token' (starts with xoxb-)",
            "Alternatively, create an Incoming Webhook under 'Incoming Webhooks'"
          ],
          docs_url: "https://api.slack.com/quickstart"
        }
      end

      def self.actions
        [
          {
            "name" => "send_message",
            "displayName" => "Send Message",
            "description" => "Send a message to a Slack channel using the Bot API",
            "props" => {
              "channel" => { "type" => "string", "required" => true, "description" => "Channel name or ID (#general or C01234)" },
              "text" => { "type" => "string", "required" => true, "description" => "Message text (Slack mrkdwn)" },
              "blocks" => { "type" => "json", "required" => false, "description" => "Block Kit blocks JSON (optional)" },
              "thread_ts" => { "type" => "string", "required" => false, "description" => "Thread timestamp for replies" }
            }
          },
          {
            "name" => "send_webhook",
            "displayName" => "Send Webhook",
            "description" => "Send a message via Incoming Webhook (simpler, no token needed)",
            "props" => {
              "text" => { "type" => "string", "required" => true, "description" => "Message text" },
              "blocks" => { "type" => "json", "required" => false, "description" => "Block Kit blocks JSON (optional)" },
              "channel" => { "type" => "string", "required" => false, "description" => "Override channel" },
              "username" => { "type" => "string", "required" => false, "description" => "Override bot username" },
              "icon_emoji" => { "type" => "string", "required" => false, "description" => "Override icon (e.g., :robot_face:)" }
            }
          },
          {
            "name" => "upload_file",
            "displayName" => "Upload File",
            "description" => "Upload a file to a Slack channel",
            "props" => {
              "channel" => { "type" => "string", "required" => true, "description" => "Channel to upload to" },
              "content" => { "type" => "string", "required" => true, "description" => "File content" },
              "filename" => { "type" => "string", "required" => true, "description" => "File name" },
              "title" => { "type" => "string", "required" => false, "description" => "File title" }
            }
          },
          {
            "name" => "add_reaction",
            "displayName" => "Add Reaction",
            "description" => "React to a message with an emoji",
            "props" => {
              "channel" => { "type" => "string", "required" => true, "description" => "Channel ID" },
              "timestamp" => { "type" => "string", "required" => true, "description" => "Message timestamp" },
              "emoji" => { "type" => "string", "required" => true, "description" => "Emoji name without colons (e.g., thumbsup)" }
            }
          },
          {
            "name" => "list_channels",
            "displayName" => "List Channels",
            "description" => "List available Slack channels",
            "props" => {
              "limit" => { "type" => "number", "required" => false, "description" => "Max channels to return (default: 100)" }
            }
          }
        ]
      end

      SLACK_API = "https://slack.com/api"

      def execute(action, **params)
        case action.to_s
        when "send_message" then send_message(params)
        when "send_webhook" then send_webhook(params)
        when "upload_file" then upload_file(params)
        when "add_reaction" then add_reaction(params)
        when "list_channels" then list_channels(params)
        else raise Connectors::ActionNotFoundError, "Unknown Slack action: #{action}"
        end
      end

      private

      def send_message(params)
        require_token!
        body = { channel: params[:channel] || default_channel, text: params[:text] }
        body[:blocks] = parse_blocks(params[:blocks]) if params[:blocks].present?
        body[:thread_ts] = params[:thread_ts] if params[:thread_ts].present?

        result = api_post("chat.postMessage", body)
        { success: true, channel: result["channel"], ts: result["ts"], message: result["message"] }
      end

      def send_webhook(params)
        url = credentials[:webhook_url]
        raise Connectors::AuthenticationError, "No webhook_url configured" unless url.present?

        body = { text: params[:text] }
        body[:blocks] = parse_blocks(params[:blocks]) if params[:blocks].present?
        body[:channel] = params[:channel] if params[:channel].present?
        body[:username] = params[:username] if params[:username].present?
        body[:icon_emoji] = params[:icon_emoji] if params[:icon_emoji].present?

        resp = faraday.post(url) do |req|
          req.headers["Content-Type"] = "application/json"
          req.body = body.to_json
        end

        unless resp.success?
          raise Connectors::Error, "Slack webhook failed: #{resp.status} #{resp.body}"
        end

        { success: true }
      end

      def upload_file(params)
        require_token!
        body = {
          channels: params[:channel] || default_channel,
          content: params[:content],
          filename: params[:filename],
          title: params[:title] || params[:filename]
        }

        result = api_post("files.upload", body)
        { success: true, file_id: result.dig("file", "id") }
      end

      def add_reaction(params)
        require_token!
        body = { channel: params[:channel], timestamp: params[:timestamp], name: params[:emoji] }
        api_post("reactions.add", body)
        { success: true }
      end

      def list_channels(params)
        require_token!
        limit = (params[:limit] || 100).to_i
        result = api_get("conversations.list", types: "public_channel,private_channel", limit: limit)
        channels = (result["channels"] || []).map { |c| { id: c["id"], name: c["name"], topic: c.dig("topic", "value") } }
        { channels: channels, count: channels.size }
      end

      def api_post(method, body)
        resp = faraday.post("#{SLACK_API}/#{method}") do |req|
          req.headers["Authorization"] = "Bearer #{token}"
          req.headers["Content-Type"] = "application/json; charset=utf-8"
          req.body = body.to_json
        end

        data = JSON.parse(resp.body)
        unless data["ok"]
          error = data["error"] || "unknown_error"
          raise Connectors::AuthenticationError, "Slack: #{error}" if %w[invalid_auth token_revoked not_authed].include?(error)
          raise Connectors::RateLimitError, "Slack rate limited" if error == "ratelimited"
          raise Connectors::Error, "Slack API error: #{error}"
        end
        data
      end

      def api_get(method, params = {})
        resp = faraday.get("#{SLACK_API}/#{method}") do |req|
          req.headers["Authorization"] = "Bearer #{token}"
          req.params = params
        end

        data = JSON.parse(resp.body)
        raise Connectors::Error, "Slack API error: #{data['error']}" unless data["ok"]
        data
      end

      def require_token!
        raise Connectors::AuthenticationError, "No Slack bot token configured" unless token.present?
      end

      def token = credentials[:token]
      def default_channel = credentials[:default_channel] || "#general"

      def parse_blocks(blocks)
        return blocks if blocks.is_a?(Array)
        JSON.parse(blocks) rescue []
      end

      def faraday
        @faraday ||= Faraday.new { |f| f.options.timeout = 15; f.options.open_timeout = 5 }
      end
    end
  end
end
