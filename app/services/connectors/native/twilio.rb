# frozen_string_literal: true

module Connectors
  module Native
    class Twilio < Base
      def self.piece_name = "twilio"
      def self.display_name = "Twilio"
      def self.description = "Send SMS, MMS, and make voice calls via Twilio"
      def self.category = "communication"
      def self.logo_url = "https://cdn.brainzlab.ai/connectors/twilio.svg"
      def self.auth_type = "BASIC"
      def self.auth_schema
        {
          type: "BASIC",
          props: {
            account_sid: { type: "string", description: "Twilio Account SID (starts with AC...)", required: true },
            auth_token: { type: "string", description: "Twilio Auth Token", required: true },
            from_number: { type: "string", description: "Default 'From' phone number (E.164 format, e.g., +1234567890)", required: false }
          }
        }
      end

      def self.setup_guide
        {
          steps: [
            "Sign up at https://www.twilio.com/try-twilio",
            "Go to Console Dashboard → Account Info",
            "Copy your Account SID and Auth Token",
            "Purchase or verify a phone number for sending SMS",
            "Enter your credentials below"
          ],
          docs_url: "https://www.twilio.com/docs/sms/quickstart"
        }
      end

      def self.actions
        [
          {
            "name" => "send_sms",
            "displayName" => "Send SMS",
            "description" => "Send an SMS or MMS message",
            "props" => {
              "to" => { "type" => "string", "required" => true, "description" => "Recipient phone number (E.164 format, e.g., +1234567890)" },
              "body" => { "type" => "string", "required" => true, "description" => "Message body (up to 1600 characters)" },
              "from" => { "type" => "string", "required" => false, "description" => "Sender phone number (overrides default)" },
              "media_url" => { "type" => "string", "required" => false, "description" => "URL of media to send (MMS)" }
            }
          },
          {
            "name" => "make_call",
            "displayName" => "Make Call",
            "description" => "Initiate a voice call with TwiML or URL",
            "props" => {
              "to" => { "type" => "string", "required" => true, "description" => "Phone number to call (E.164)" },
              "from" => { "type" => "string", "required" => false, "description" => "Caller phone number (overrides default)" },
              "twiml" => { "type" => "string", "required" => false, "description" => "TwiML instructions (e.g., <Say>Hello</Say>)" },
              "url" => { "type" => "string", "required" => false, "description" => "URL returning TwiML instructions" }
            }
          },
          {
            "name" => "list_messages",
            "displayName" => "List Messages",
            "description" => "List recent SMS/MMS messages",
            "props" => {
              "to" => { "type" => "string", "required" => false, "description" => "Filter by recipient" },
              "from" => { "type" => "string", "required" => false, "description" => "Filter by sender" },
              "limit" => { "type" => "number", "required" => false, "description" => "Max messages to return (default: 20)" }
            }
          },
          {
            "name" => "get_message",
            "displayName" => "Get Message",
            "description" => "Get details of a specific message",
            "props" => {
              "message_sid" => { "type" => "string", "required" => true, "description" => "Message SID (starts with SM...)" }
            }
          }
        ]
      end

      def execute(action, **params)
        case action.to_s
        when "send_sms" then send_sms(params)
        when "make_call" then make_call(params)
        when "list_messages" then list_messages(params)
        when "get_message" then get_message(params)
        else raise Connectors::ActionNotFoundError, "Unknown Twilio action: #{action}"
        end
      end

      private

      def send_sms(params)
        body = {
          To: params[:to],
          From: params[:from] || from_number,
          Body: params[:body]
        }
        body[:MediaUrl] = params[:media_url] if params[:media_url].present?

        result = api_post("Messages.json", body)
        { success: true, sid: result["sid"], status: result["status"], to: result["to"], from: result["from"] }
      end

      def make_call(params)
        body = {
          To: params[:to],
          From: params[:from] || from_number
        }

        if params[:twiml].present?
          body[:Twiml] = params[:twiml]
        elsif params[:url].present?
          body[:Url] = params[:url]
        else
          raise Connectors::Error, "Either 'twiml' or 'url' is required for make_call"
        end

        result = api_post("Calls.json", body)
        { success: true, sid: result["sid"], status: result["status"], to: result["to"], from: result["from"] }
      end

      def list_messages(params)
        query = {}
        query[:To] = params[:to] if params[:to].present?
        query[:From] = params[:from] if params[:from].present?
        query[:PageSize] = (params[:limit] || 20).to_i

        result = api_get("Messages.json", query)
        messages = (result["messages"] || []).map do |m|
          { sid: m["sid"], to: m["to"], from: m["from"], body: m["body"], status: m["status"], date_sent: m["date_sent"] }
        end
        { messages: messages, count: messages.size }
      end

      def get_message(params)
        result = api_get("Messages/#{params[:message_sid]}.json")
        { sid: result["sid"], to: result["to"], from: result["from"], body: result["body"], status: result["status"], date_sent: result["date_sent"], price: result["price"] }
      end

      def api_post(path, body)
        resp = faraday.post("#{api_base}/#{path}") do |req|
          req.headers["Authorization"] = basic_auth_header
          req.headers["Content-Type"] = "application/x-www-form-urlencoded"
          req.body = URI.encode_www_form(body)
        end

        handle_response(resp)
      end

      def api_get(path, params = {})
        resp = faraday.get("#{api_base}/#{path}") do |req|
          req.headers["Authorization"] = basic_auth_header
          req.params = params
        end

        handle_response(resp)
      end

      def handle_response(resp)
        data = JSON.parse(resp.body)

        unless resp.success?
          error_msg = data.dig("message") || data.dig("detail") || "HTTP #{resp.status}"
          raise Connectors::AuthenticationError, "Twilio: #{error_msg}" if resp.status == 401
          raise Connectors::RateLimitError, "Twilio rate limited" if resp.status == 429
          raise Connectors::Error, "Twilio API error: #{error_msg}"
        end

        data
      end

      def api_base
        "https://api.twilio.com/2010-04-01/Accounts/#{account_sid}"
      end

      def basic_auth_header
        "Basic #{Base64.strict_encode64("#{account_sid}:#{auth_token}")}"
      end

      def account_sid = credentials[:account_sid]
      def auth_token = credentials[:auth_token]
      def from_number = credentials[:from_number]

      def faraday
        @faraday ||= Faraday.new { |f| f.options.timeout = 15; f.options.open_timeout = 5 }
      end
    end
  end
end
