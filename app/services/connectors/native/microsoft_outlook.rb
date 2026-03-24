# frozen_string_literal: true

module Connectors
  module Native
    class MicrosoftOutlook < Base
      def self.piece_name = "microsoft-outlook"
      def self.display_name = "Microsoft Outlook"
      def self.description = "Read and send emails, manage calendar via Microsoft 365"
      def self.category = "communication"
      def self.logo_url = "https://cdn.brainzlab.ai/connectors/microsoft-outlook.svg"
      def self.auth_type = "OAUTH2"

      def self.auth_schema
        {
          type: "OAUTH2",
          authUrl: "https://login.microsoftonline.com/common/oauth2/v2.0/authorize",
          tokenUrl: "https://login.microsoftonline.com/common/oauth2/v2.0/token",
          scope: "openid profile email Mail.Read Mail.Send Calendars.ReadWrite User.Read offline_access",
          pkce: true
        }
      end

      def self.setup_guide
        {
          steps: [
            "Go to https://portal.azure.com > Azure Active Directory > App registrations > New registration",
            "Supported account types: Accounts in any organizational directory and personal Microsoft accounts",
            "Redirect URI: Web > {VAULT_URL}/oauth/callback",
            "Certificates & secrets > New client secret > copy Value",
            "API permissions > Add: Mail.Read, Mail.Send, Calendars.ReadWrite, User.Read",
            "Set ENV: VAULT_OAUTH_MICROSOFT_OUTLOOK_CLIENT_ID and VAULT_OAUTH_MICROSOFT_OUTLOOK_CLIENT_SECRET"
          ],
          docs_url: "https://learn.microsoft.com/en-us/graph/auth-v2-user"
        }
      end

      def self.actions
        [
          { "name" => "list_messages", "displayName" => "List Emails", "description" => "List recent email messages",
            "props" => { "top" => { "type" => "number", "required" => false, "description" => "Max results (default: 20)" },
              "folder" => { "type" => "string", "required" => false, "description" => "Folder: inbox, sentitems, drafts" } } },
          { "name" => "send_mail", "displayName" => "Send Email", "description" => "Send an email message",
            "props" => { "to" => { "type" => "string", "required" => true, "description" => "Recipient email" },
              "subject" => { "type" => "string", "required" => true }, "body" => { "type" => "string", "required" => true },
              "content_type" => { "type" => "string", "required" => false, "description" => "Text or HTML (default: Text)" } } },
          { "name" => "list_events", "displayName" => "List Calendar Events", "description" => "List upcoming calendar events",
            "props" => { "top" => { "type" => "number", "required" => false } } },
          { "name" => "get_profile", "displayName" => "Get Profile", "description" => "Get the authenticated user's profile",
            "props" => {} }
        ]
      end

      GRAPH_API = "https://graph.microsoft.com/v1.0"

      def execute(action, **params)
        case action.to_s
        when "list_messages"
          folder = params[:folder] || "inbox"
          api_get("/me/mailFolders/#{folder}/messages?$top=#{params[:top] || 20}&$select=subject,from,receivedDateTime,isRead")
        when "send_mail" then send_mail(params)
        when "list_events" then api_get("/me/events?$top=#{params[:top] || 20}&$select=subject,start,end,location")
        when "get_profile" then api_get("/me")
        else raise Connectors::ActionNotFoundError, "Unknown Microsoft Outlook action: #{action}"
        end
      end

      private

      def send_mail(params)
        body = {
          message: {
            subject: params[:subject],
            body: { contentType: params[:content_type] || "Text", content: params[:body] },
            toRecipients: [{ emailAddress: { address: params[:to] } }]
          }
        }
        resp = faraday.post("#{GRAPH_API}/me/sendMail") do |r|
          r.headers["Authorization"] = "Bearer #{access_token}"
          r.headers["Content-Type"] = "application/json"
          r.body = body.to_json
        end
        raise Connectors::Error, "Send failed: #{resp.status}" unless resp.success?
        { success: true }
      end

      def access_token = credentials[:access_token] || raise(Connectors::AuthenticationError, "No access token")

      def api_get(path)
        resp = faraday.get("#{GRAPH_API}#{path}") { |r| r.headers["Authorization"] = "Bearer #{access_token}" }
        raise Connectors::AuthenticationError, "Microsoft: unauthorized" if resp.status == 401
        data = JSON.parse(resp.body)
        raise Connectors::Error, "Microsoft Graph error (#{resp.status}): #{data.dig('error', 'message')}" unless resp.success?
        data
      end

      def faraday = @faraday ||= Faraday.new { |f| f.options.timeout = 15; f.options.open_timeout = 5 }
    end
  end
end
