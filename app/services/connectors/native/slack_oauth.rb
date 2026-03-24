# frozen_string_literal: true

module Connectors
  module Native
    class SlackOauth < Base
      def self.piece_name = "slack-oauth"
      def self.display_name = "Slack (OAuth)"
      def self.description = "Connect to Slack via OAuth for full API access with automatic token refresh"
      def self.category = "communication"
      def self.logo_url = "https://cdn.brainzlab.ai/connectors/slack.svg"
      def self.auth_type = "OAUTH2"

      def self.auth_schema
        {
          type: "OAUTH2",
          authUrl: "https://slack.com/oauth/v2/authorize",
          tokenUrl: "https://slack.com/api/oauth.v2.access",
          scope: "chat:write channels:read channels:history users:read files:write reactions:write",
          pkce: false
        }
      end

      def self.setup_guide
        {
          steps: [
            "Go to https://api.slack.com/apps and create a new app (From scratch)",
            "Under OAuth & Permissions, add Redirect URL: {VAULT_URL}/oauth/callback",
            "Add Bot Token Scopes: chat:write, channels:read, channels:history, users:read, files:write, reactions:write",
            "Under Basic Information, copy Client ID and Client Secret",
            "Set ENV: VAULT_OAUTH_SLACK_OAUTH_CLIENT_ID and VAULT_OAUTH_SLACK_OAUTH_CLIENT_SECRET"
          ],
          docs_url: "https://api.slack.com/authentication/oauth-v2"
        }
      end

      def self.actions
        [
          {
            "name" => "send_message",
            "displayName" => "Send Message",
            "description" => "Send a message to a Slack channel",
            "props" => {
              "channel" => { "type" => "string", "required" => true, "description" => "Channel name or ID" },
              "text" => { "type" => "string", "required" => true, "description" => "Message text (mrkdwn)" },
              "blocks" => { "type" => "json", "required" => false, "description" => "Block Kit blocks JSON" },
              "thread_ts" => { "type" => "string", "required" => false, "description" => "Thread timestamp for replies" }
            }
          },
          {
            "name" => "list_channels",
            "displayName" => "List Channels",
            "description" => "List available Slack channels",
            "props" => {
              "limit" => { "type" => "number", "required" => false, "description" => "Max channels (default: 100)" }
            }
          },
          {
            "name" => "upload_file",
            "displayName" => "Upload File",
            "description" => "Upload a file to a Slack channel",
            "props" => {
              "channel" => { "type" => "string", "required" => true, "description" => "Channel to upload to" },
              "content" => { "type" => "string", "required" => true, "description" => "File content" },
              "filename" => { "type" => "string", "required" => true, "description" => "File name" }
            }
          }
        ]
      end

      SLACK_API = "https://slack.com/api"

      def execute(action, **params)
        case action.to_s
        when "send_message" then send_message(params)
        when "list_channels" then list_channels(params)
        when "upload_file" then upload_file(params)
        else raise Connectors::ActionNotFoundError, "Unknown Slack OAuth action: #{action}"
        end
      end

      private

      def send_message(params)
        body = { channel: params[:channel], text: params[:text] }
        body[:blocks] = parse_json(params[:blocks]) if params[:blocks].present?
        body[:thread_ts] = params[:thread_ts] if params[:thread_ts].present?
        result = api_post("chat.postMessage", body)
        { success: true, channel: result["channel"], ts: result["ts"] }
      end

      def list_channels(params)
        limit = (params[:limit] || 100).to_i
        result = api_get("conversations.list", types: "public_channel,private_channel", limit: limit)
        channels = (result["channels"] || []).map { |c| { id: c["id"], name: c["name"] } }
        { channels: channels, count: channels.size }
      end

      def upload_file(params)
        body = { channels: params[:channel], content: params[:content], filename: params[:filename] }
        result = api_post("files.upload", body)
        { success: true, file_id: result.dig("file", "id") }
      end

      def access_token
        credentials[:access_token] || raise(Connectors::AuthenticationError, "No access token")
      end

      def api_post(method, body)
        resp = faraday.post("#{SLACK_API}/#{method}") do |r|
          r.headers["Authorization"] = "Bearer #{access_token}"
          r.headers["Content-Type"] = "application/json; charset=utf-8"
          r.body = body.to_json
        end
        data = JSON.parse(resp.body)
        raise Connectors::AuthenticationError, "Slack: #{data['error']}" if %w[invalid_auth token_revoked].include?(data["error"])
        raise Connectors::Error, "Slack API error: #{data['error']}" unless data["ok"]
        data
      end

      def api_get(method, params = {})
        resp = faraday.get("#{SLACK_API}/#{method}") do |r|
          r.headers["Authorization"] = "Bearer #{access_token}"
          r.params = params
        end
        data = JSON.parse(resp.body)
        raise Connectors::Error, "Slack API error: #{data['error']}" unless data["ok"]
        data
      end

      def parse_json(val)
        return val if val.is_a?(Array)
        JSON.parse(val) rescue []
      end

      def faraday
        @faraday ||= Faraday.new { |f| f.options.timeout = 15; f.options.open_timeout = 5 }
      end
    end
  end
end
