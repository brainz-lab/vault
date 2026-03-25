# frozen_string_literal: true

module Connectors
  module Native
    class Gmail < Base
      def self.piece_name = "gmail"
      def self.display_name = "Gmail"
      def self.description = "Read, send, and manage emails with Gmail"
      def self.category = "communication"
      def self.logo_url = "https://cdn.brainzlab.ai/connectors/gmail.svg"
      def self.auth_type = "OAUTH2"

      def self.auth_schema
        {
          type: "OAUTH2",
          authUrl: "https://accounts.google.com/o/oauth2/v2/auth?access_type=offline&prompt=consent",
          tokenUrl: "https://oauth2.googleapis.com/token",
          scope: "https://www.googleapis.com/auth/gmail.modify",
          pkce: false
        }
      end

      def self.setup_guide
        {
          steps: [
            "Go to https://console.cloud.google.com and create or select a project",
            "Enable the Gmail API in APIs & Services > Library",
            "Configure the OAuth consent screen (APIs & Services > OAuth consent screen)",
            "Create OAuth credentials: APIs & Services > Credentials > Create Credentials > OAuth client ID",
            "Set Authorized redirect URI to: {VAULT_URL}/oauth/callback",
            "Copy Client ID and Client Secret",
            "Set ENV: VAULT_OAUTH_GMAIL_CLIENT_ID and VAULT_OAUTH_GMAIL_CLIENT_SECRET"
          ],
          docs_url: "https://developers.google.com/gmail/api/quickstart"
        }
      end

      def self.actions
        [
          {
            "name" => "list_messages",
            "displayName" => "List Messages",
            "description" => "List messages in the mailbox",
            "props" => {
              "query" => { "type" => "string", "required" => false, "description" => "Gmail search query (e.g. from:user@example.com is:unread)" },
              "label" => { "type" => "string", "required" => false, "description" => "Label filter: INBOX, SENT, DRAFT, SPAM, TRASH, STARRED, UNREAD" },
              "limit" => { "type" => "number", "required" => false, "description" => "Max results (default: 20)" }
            }
          },
          {
            "name" => "get_message",
            "displayName" => "Get Message",
            "description" => "Get the full content of an email message",
            "props" => {
              "message_id" => { "type" => "string", "required" => true, "description" => "Message ID" }
            }
          },
          {
            "name" => "send_email",
            "displayName" => "Send Email",
            "description" => "Send a new email message",
            "props" => {
              "to" => { "type" => "string", "required" => true, "description" => "Recipient email address(es), comma-separated" },
              "subject" => { "type" => "string", "required" => true, "description" => "Email subject" },
              "body" => { "type" => "string", "required" => true, "description" => "Email body (plain text or HTML)" },
              "cc" => { "type" => "string", "required" => false, "description" => "CC recipients, comma-separated" },
              "bcc" => { "type" => "string", "required" => false, "description" => "BCC recipients, comma-separated" },
              "html" => { "type" => "boolean", "required" => false, "description" => "Send as HTML (default: false)" }
            }
          },
          {
            "name" => "reply_to_message",
            "displayName" => "Reply to Message",
            "description" => "Reply to an existing email thread",
            "props" => {
              "message_id" => { "type" => "string", "required" => true, "description" => "Message ID to reply to" },
              "body" => { "type" => "string", "required" => true, "description" => "Reply body (plain text or HTML)" },
              "html" => { "type" => "boolean", "required" => false, "description" => "Send as HTML (default: false)" }
            }
          },
          {
            "name" => "search_messages",
            "displayName" => "Search Messages",
            "description" => "Search emails using Gmail search syntax",
            "props" => {
              "query" => { "type" => "string", "required" => true, "description" => "Gmail search query" },
              "limit" => { "type" => "number", "required" => false, "description" => "Max results (default: 20)" }
            }
          },
          {
            "name" => "modify_labels",
            "displayName" => "Modify Labels",
            "description" => "Add or remove labels from a message (mark read/unread, archive, star, etc.)",
            "props" => {
              "message_id" => { "type" => "string", "required" => true, "description" => "Message ID" },
              "add_labels" => { "type" => "json", "required" => false, "description" => "Labels to add [\"STARRED\", \"IMPORTANT\"]" },
              "remove_labels" => { "type" => "json", "required" => false, "description" => "Labels to remove [\"UNREAD\", \"INBOX\"]" }
            }
          },
          {
            "name" => "trash_message",
            "displayName" => "Trash Message",
            "description" => "Move a message to trash",
            "props" => {
              "message_id" => { "type" => "string", "required" => true, "description" => "Message ID" }
            }
          },
          {
            "name" => "list_labels",
            "displayName" => "List Labels",
            "description" => "List all labels in the mailbox",
            "props" => {}
          }
        ]
      end

      GMAIL_API = "https://gmail.googleapis.com/gmail/v1/users/me"

      def execute(action, **params)
        case action.to_s
        when "list_messages" then list_messages(params)
        when "get_message" then get_message(params)
        when "send_email" then send_email(params)
        when "reply_to_message" then reply_to_message(params)
        when "search_messages" then search_messages(params)
        when "modify_labels" then modify_labels(params)
        when "trash_message" then trash_message(params)
        when "list_labels" then list_labels(params)
        else raise Connectors::ActionNotFoundError, "Unknown Gmail action: #{action}"
        end
      end

      private

      def list_messages(params)
        limit = (params[:limit] || 20).to_i
        query_params = { maxResults: limit }
        query_params[:q] = params[:query] if params[:query].present?
        query_params[:labelIds] = params[:label] if params[:label].present?

        url = "#{GMAIL_API}/messages?#{URI.encode_www_form(query_params)}"
        resp = api_get(url)

        messages = (resp["messages"] || []).map do |m|
          msg = api_get("#{GMAIL_API}/messages/#{m["id"]}?format=metadata&metadataHeaders=From&metadataHeaders=To&metadataHeaders=Subject&metadataHeaders=Date")
          format_message_summary(msg)
        end
        { messages: messages, count: messages.size }
      end

      def get_message(params)
        resp = api_get("#{GMAIL_API}/messages/#{params[:message_id]}?format=full")
        format_message_full(resp)
      end

      def send_email(params)
        content_type = params[:html] ? "text/html" : "text/plain"
        raw = build_raw_email(
          to: params[:to], subject: params[:subject], body: params[:body],
          cc: params[:cc], bcc: params[:bcc], content_type: content_type
        )

        resp = api_post("#{GMAIL_API}/messages/send", { raw: raw })
        { id: resp["id"], thread_id: resp["threadId"], label_ids: resp["labelIds"] }
      end

      def reply_to_message(params)
        original = api_get("#{GMAIL_API}/messages/#{params[:message_id]}?format=metadata&metadataHeaders=From&metadataHeaders=To&metadataHeaders=Subject&metadataHeaders=Message-ID")

        headers = extract_headers(original)
        subject = headers["Subject"]
        subject = "Re: #{subject}" unless subject&.start_with?("Re:")
        to = headers["From"]
        in_reply_to = headers["Message-ID"]

        content_type = params[:html] ? "text/html" : "text/plain"
        raw = build_raw_email(
          to: to, subject: subject, body: params[:body],
          content_type: content_type, in_reply_to: in_reply_to,
          references: in_reply_to
        )

        resp = api_post("#{GMAIL_API}/messages/send", { raw: raw, threadId: original["threadId"] })
        { id: resp["id"], thread_id: resp["threadId"] }
      end

      def search_messages(params)
        list_messages(params)
      end

      def modify_labels(params)
        body = {}
        if params[:add_labels].present?
          labels = params[:add_labels].is_a?(String) ? JSON.parse(params[:add_labels]) : params[:add_labels]
          body[:addLabelIds] = labels
        end
        if params[:remove_labels].present?
          labels = params[:remove_labels].is_a?(String) ? JSON.parse(params[:remove_labels]) : params[:remove_labels]
          body[:removeLabelIds] = labels
        end

        resp = api_post("#{GMAIL_API}/messages/#{params[:message_id]}/modify", body)
        { id: resp["id"], label_ids: resp["labelIds"] }
      end

      def trash_message(params)
        resp = api_post("#{GMAIL_API}/messages/#{params[:message_id]}/trash", {})
        { trashed: true, id: resp["id"] }
      end

      def list_labels(_params)
        resp = api_get("#{GMAIL_API}/labels")
        labels = (resp["labels"] || []).map do |l|
          { id: l["id"], name: l["name"], type: l["type"],
            messages_total: l["messagesTotal"], messages_unread: l["messagesUnread"] }
        end
        { labels: labels, count: labels.size }
      end

      def build_raw_email(to:, subject:, body:, cc: nil, bcc: nil, content_type: "text/plain", in_reply_to: nil, references: nil)
        lines = []
        lines << "To: #{to}"
        lines << "Cc: #{cc}" if cc.present?
        lines << "Bcc: #{bcc}" if bcc.present?
        lines << "Subject: #{subject}"
        lines << "Content-Type: #{content_type}; charset=UTF-8"
        lines << "In-Reply-To: #{in_reply_to}" if in_reply_to.present?
        lines << "References: #{references}" if references.present?
        lines << ""
        lines << body

        Base64.urlsafe_encode64(lines.join("\r\n"))
      end

      def extract_headers(message)
        headers = {}
        (message.dig("payload", "headers") || []).each do |h|
          headers[h["name"]] = h["value"]
        end
        headers
      end

      def format_message_summary(msg)
        headers = extract_headers(msg)
        {
          id: msg["id"],
          thread_id: msg["threadId"],
          from: headers["From"],
          to: headers["To"],
          subject: headers["Subject"],
          date: headers["Date"],
          snippet: msg["snippet"],
          label_ids: msg["labelIds"]
        }
      end

      def format_message_full(msg)
        headers = extract_headers(msg)
        body = extract_body(msg["payload"])
        {
          id: msg["id"],
          thread_id: msg["threadId"],
          from: headers["From"],
          to: headers["To"],
          cc: headers["Cc"],
          subject: headers["Subject"],
          date: headers["Date"],
          body: body,
          snippet: msg["snippet"],
          label_ids: msg["labelIds"],
          size_estimate: msg["sizeEstimate"]
        }
      end

      def extract_body(payload)
        return Base64.urlsafe_decode64(payload["body"]["data"]) if payload.dig("body", "data").present?

        parts = payload["parts"] || []

        # Prefer text/plain, fallback to text/html
        text_part = parts.find { |p| p["mimeType"] == "text/plain" }
        html_part = parts.find { |p| p["mimeType"] == "text/html" }
        part = text_part || html_part

        return Base64.urlsafe_decode64(part["body"]["data"]) if part&.dig("body", "data").present?

        # Nested multipart
        multipart = parts.find { |p| p["mimeType"]&.start_with?("multipart/") }
        return extract_body(multipart) if multipart

        ""
      end

      def access_token
        credentials[:access_token] || raise(Connectors::AuthenticationError, "No access token. Complete OAuth flow first.")
      end

      def api_get(url)
        resp = faraday.get(url) { |r| r.headers["Authorization"] = "Bearer #{access_token}" }
        handle_response(resp)
      end

      def api_post(url, body)
        resp = faraday.post(url) do |r|
          r.headers["Authorization"] = "Bearer #{access_token}"
          r.headers["Content-Type"] = "application/json"
          r.body = body.to_json
        end
        handle_response(resp)
      end

      def handle_response(resp)
        data = JSON.parse(resp.body)
        if resp.status == 401
          raise Connectors::AuthenticationError, "Google API: token expired or revoked"
        elsif !resp.success?
          error = data.dig("error", "message") || resp.body
          raise Connectors::Error, "Google API error (#{resp.status}): #{error}"
        end
        data
      end

      def faraday
        @faraday ||= Faraday.new { |f| f.options.timeout = 30; f.options.open_timeout = 5 }
      end
    end
  end
end
