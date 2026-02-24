require "net/smtp"
require "net/imap"

module Connectors
  module Native
    class Email < Base
      def self.piece_name = "email"
      def self.display_name = "Email"
      def self.description = "Send emails via SMTP and fetch from IMAP"
      def self.category = "communication"
      def self.auth_type = "CUSTOM_AUTH"
      def self.auth_schema
        {
          type: "CUSTOM_AUTH",
          props: {
            username: { type: "string", description: "Email username", required: true },
            password: { type: "string", description: "Email password", required: true },
            smtp_host: { type: "string", description: "SMTP host", required: true },
            smtp_port: { type: "number", description: "SMTP port (default: 587)", required: false },
            imap_host: { type: "string", description: "IMAP host", required: false },
            imap_port: { type: "number", description: "IMAP port (default: 993)", required: false },
            from: { type: "string", description: "From address (default: username)", required: false }
          }
        }
      end

      def self.actions
        [
          {
            "name" => "send_email",
            "displayName" => "Send Email",
            "description" => "Send an email via SMTP",
            "props" => {
              "to" => { "type" => "string", "required" => true, "description" => "Recipient email" },
              "subject" => { "type" => "string", "required" => true, "description" => "Email subject" },
              "body" => { "type" => "string", "required" => true, "description" => "Email body (plain text)" },
              "html_body" => { "type" => "string", "required" => false, "description" => "Email body (HTML)" },
              "cc" => { "type" => "string", "required" => false, "description" => "CC recipients (comma-separated)" },
              "bcc" => { "type" => "string", "required" => false, "description" => "BCC recipients (comma-separated)" }
            }
          },
          {
            "name" => "fetch_emails",
            "displayName" => "Fetch Emails",
            "description" => "Fetch emails from an IMAP mailbox",
            "props" => {
              "folder" => { "type" => "string", "required" => false, "description" => "Mailbox folder (default: INBOX)" },
              "limit" => { "type" => "number", "required" => false, "description" => "Max emails to fetch (default: 10)" },
              "since" => { "type" => "string", "required" => false, "description" => "Fetch since date (YYYY-MM-DD)" }
            }
          }
        ]
      end

      def execute(action, **params)
        case action.to_s
        when "send_email" then send_email(params)
        when "fetch_emails" then fetch_emails(params)
        else raise Connectors::ActionNotFoundError, "Unknown action: #{action}"
        end
      end

      private

      def send_email(params)
        from = credentials[:from] || credentials[:username]
        message = build_message(from: from, to: params[:to], subject: params[:subject], body: params[:body], html_body: params[:html_body], cc: params[:cc])

        all_recipients = [ params[:to] ]
        all_recipients += params[:cc].split(",").map(&:strip) if params[:cc].present?
        all_recipients += params[:bcc].split(",").map(&:strip) if params[:bcc].present?

        smtp = Net::SMTP.new(smtp_host, smtp_port)
        smtp.enable_starttls_auto if smtp_port == 587

        smtp.start(smtp_domain, credentials[:username], credentials[:password], :login) do |server|
          server.send_message(message, from, all_recipients)
        end

        { success: true, to: params[:to], subject: params[:subject] }
      rescue Net::SMTPAuthenticationError => e
        raise Connectors::AuthenticationError, "SMTP authentication failed: #{e.message}"
      rescue Net::SMTPError, Net::OpenTimeout, Net::ReadTimeout => e
        raise Connectors::Error, "SMTP error: #{e.message}"
      end

      def fetch_emails(params)
        folder = params[:folder] || "INBOX"
        limit = (params[:limit] || 10).to_i

        imap = Net::IMAP.new(imap_host, port: imap_port, ssl: true)
        imap.login(credentials[:username], credentials[:password])
        imap.select(folder)

        search_criteria = params[:since].present? ? [ "SINCE", params[:since] ] : [ "ALL" ]
        message_ids = imap.search(search_criteria).last(limit)

        emails = message_ids.map do |id|
          envelope = imap.fetch(id, "ENVELOPE").first.attr["ENVELOPE"]
          {
            id: id,
            subject: envelope.subject,
            from: envelope.from&.map { |a| "#{a.name} <#{a.mailbox}@#{a.host}>" }&.join(", "),
            date: envelope.date,
            to: envelope.to&.map { |a| "#{a.mailbox}@#{a.host}" }&.join(", ")
          }
        end

        imap.logout
        imap.disconnect

        { emails: emails, count: emails.size, folder: folder }
      rescue Net::IMAP::NoResponseError, Net::IMAP::BadResponseError => e
        raise Connectors::AuthenticationError, "IMAP error: #{e.message}"
      rescue StandardError => e
        raise Connectors::Error, "Email fetch error: #{e.message}"
      end

      def build_message(from:, to:, subject:, body:, html_body: nil, cc: nil)
        boundary = "----=_Part_#{SecureRandom.hex(8)}"
        msg = "From: #{from}\r\nTo: #{to}\r\n"
        msg += "Cc: #{cc}\r\n" if cc.present?
        msg += "Subject: #{subject}\r\nMIME-Version: 1.0\r\nDate: #{Time.current.rfc2822}\r\n"

        if html_body.present?
          msg += "Content-Type: multipart/alternative; boundary=\"#{boundary}\"\r\n\r\n"
          msg += "--#{boundary}\r\nContent-Type: text/plain; charset=UTF-8\r\n\r\n#{body}\r\n"
          msg += "--#{boundary}\r\nContent-Type: text/html; charset=UTF-8\r\n\r\n#{html_body}\r\n"
          msg += "--#{boundary}--\r\n"
        else
          msg += "Content-Type: text/plain; charset=UTF-8\r\n\r\n#{body}"
        end

        msg
      end

      def smtp_host = credentials[:smtp_host] || "localhost"
      def smtp_port = (credentials[:smtp_port] || 587).to_i
      def smtp_domain = credentials[:smtp_domain] || smtp_host
      def imap_host = credentials[:imap_host] || smtp_host
      def imap_port = (credentials[:imap_port] || 993).to_i
    end
  end
end
