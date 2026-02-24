module Connectors
  module Native
    class Webhook < Base
      def self.piece_name = "webhook"
      def self.display_name = "Webhook"
      def self.description = "Send HTTP webhook requests with optional HMAC signing"
      def self.category = "automation"
      def self.auth_type = "SECRET_TEXT"
      def self.auth_schema
        { type: "SECRET_TEXT", props: { secret: { type: "string", description: "HMAC signing secret (optional)" } } }
      end

      def self.actions
        [
          {
            "name" => "send",
            "displayName" => "Send Webhook",
            "description" => "Send an HTTP request to a URL",
            "props" => {
              "url" => { "type" => "string", "required" => true, "description" => "Target URL" },
              "method" => { "type" => "string", "required" => false, "description" => "HTTP method (default: POST)" },
              "headers" => { "type" => "object", "required" => false, "description" => "Custom headers" },
              "body" => { "type" => "object", "required" => false, "description" => "Request body" }
            }
          }
        ]
      end

      def execute(action, **params)
        case action.to_s
        when "send" then send_webhook(params)
        else raise Connectors::ActionNotFoundError, "Unknown action: #{action}"
        end
      end

      private

      def send_webhook(params)
        url = params[:url]
        method = (params[:method] || "POST").upcase
        headers = params[:headers] || {}
        body = params[:body]
        secret = credentials[:secret]

        if secret.present? && body.present?
          signature = OpenSSL::HMAC.hexdigest("SHA256", secret, body.to_json)
          headers["X-Webhook-Signature"] = "sha256=#{signature}"
        end

        response = Faraday.new do |f|
          f.request :json
          f.response :json
          f.options.timeout = 30
        end.run_request(method.downcase.to_sym, url, body, headers)

        {
          status: response.status,
          body: response.body,
          headers: response.headers.to_h
        }
      rescue Faraday::Error => e
        raise Connectors::Error, "Webhook request failed: #{e.message}"
      end
    end
  end
end
