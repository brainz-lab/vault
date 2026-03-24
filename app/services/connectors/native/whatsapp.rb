# frozen_string_literal: true

module Connectors
  module Native
    class Whatsapp < Base
      def self.piece_name = "whatsapp"
      def self.display_name = "WhatsApp"
      def self.description = "Send and receive WhatsApp messages directly from your campaigns"
      def self.category = "communication"
      def self.logo_url = "https://cdn.brainzlab.ai/connectors/whatsapp.svg"
      def self.auth_type = "CUSTOM_AUTH"
      def self.auth_schema
        {
          type: "CUSTOM_AUTH",
          props: {
            instance_name: { type: "string", description: "Auto-generated instance identifier", required: false }
          }
        }
      end

      def self.setup_guide
        {
          steps: [
            { title: "Save the connector", description: "Click Save — the WhatsApp session is created automatically" },
            { title: "Scan QR code", description: "Open WhatsApp on your phone → Linked Devices → Scan the QR code" },
            { title: "Ready!", description: "Your WhatsApp is connected. Campaigns can now send messages" }
          ]
        }
      end

      def self.actions
        [
          {
            "name" => "send_text",
            "displayName" => "Send Text Message",
            "description" => "Send a text message via WhatsApp",
            "props" => {
              "to" => { "type" => "string", "required" => true, "description" => "Phone number with country code" },
              "body" => { "type" => "string", "required" => true, "description" => "Message text" }
            }
          },
          {
            "name" => "send_media",
            "displayName" => "Send Media",
            "description" => "Send an image, document, or audio via WhatsApp",
            "props" => {
              "to" => { "type" => "string", "required" => true, "description" => "Phone number with country code" },
              "media_url" => { "type" => "string", "required" => true, "description" => "URL of the media file" },
              "media_type" => { "type" => "string", "required" => false, "description" => "Type: image, document, audio, video" },
              "caption" => { "type" => "string", "required" => false, "description" => "Caption for the media" }
            }
          },
          {
            "name" => "check_number",
            "displayName" => "Check WhatsApp Number",
            "description" => "Verify if a phone number is registered on WhatsApp",
            "props" => {
              "phone" => { "type" => "string", "required" => true, "description" => "Phone number to check" }
            }
          },
          {
            "name" => "get_status",
            "displayName" => "Get Connection Status",
            "description" => "Check if WhatsApp is connected",
            "props" => {}
          },
          {
            "name" => "get_qr_code",
            "displayName" => "Get QR Code",
            "description" => "Get QR code for connecting WhatsApp",
            "props" => {}
          },
          {
            "name" => "create_instance",
            "displayName" => "Create Instance",
            "description" => "Create a new WhatsApp session",
            "props" => {
              "instance_name" => { "type" => "string", "required" => true, "description" => "Session name" },
              "webhook_url" => { "type" => "string", "required" => false, "description" => "Webhook URL for events" }
            }
          },
          {
            "name" => "delete_instance",
            "displayName" => "Delete Instance",
            "description" => "Delete WhatsApp session and cleanup",
            "props" => {}
          },
          {
            "name" => "test_connection",
            "displayName" => "Test Connection",
            "description" => "Test the WhatsApp connection",
            "props" => {}
          }
        ]
      end

      def execute(action, **params)
        case action.to_s
        when "send_text" then send_text(params)
        when "send_media" then send_media(params)
        when "check_number" then check_number(params)
        when "get_status" then get_status
        when "get_qr_code" then get_qr_code
        when "create_instance" then create_instance(params)
        when "logout" then logout_instance
        when "delete_instance" then delete_instance
        when "test_connection" then get_status
        else raise Connectors::ActionNotFoundError, "Unknown WhatsApp action: #{action}"
        end
      end

      private

      def api_url
        url = credentials[:api_url] || ENV.fetch("EVOLUTION_API_URL", "http://localhost:8282")
        url.chomp("/")
      end

      def api_key
        credentials[:api_key] || ENV.fetch("EVOLUTION_API_KEY", "brainzlab_evo_dev_key")
      end

      def session_name
        credentials[:instance_name] || "default"
      end

      # ==================== Actions ====================

      def send_text(params)
        phone = normalize_phone(params[:to])
        result = api_post("/chat/send/text", {
          Phone: phone,
          Body: params[:body]
        })
        {
          success: true,
          message_id: result.dig("data", "Id") || result.dig("data", "id") || SecureRandom.uuid,
          to: phone,
          provider: "wuzapi"
        }
      end

      def send_media(params)
        phone = normalize_phone(params[:to])
        media_type = (params[:media_type] || "image").to_s

        endpoint = case media_type
        when "image" then "/chat/send/image"
        when "video" then "/chat/send/video"
        when "document" then "/chat/send/document"
        when "audio" then "/chat/send/audio"
        else "/chat/send/document"
        end

        result = api_post(endpoint, {
          Phone: phone,
          Url: params[:media_url],
          Caption: params[:caption]
        }.compact)
        {
          success: true,
          message_id: result.dig("data", "Id") || SecureRandom.uuid,
          to: phone,
          provider: "wuzapi"
        }
      end

      def check_number(params)
        phone = normalize_phone(params[:phone])
        result = api_post("/user/check", { Phone: [phone] })
        users = result.dig("data", "Users") || {}
        exists = users.values.any? { |v| v.is_a?(Hash) && v["Devices"].present? }
        { exists: exists, phone: phone }
      end

      def get_status
        result = api_get("/session/status")
        data = result["data"] || {}
        {
          connected: data["connected"] == true || data["Connected"] == true,
          logged_in: data["loggedIn"] == true || data["LoggedIn"] == true,
          instance: session_name,
          provider: "wuzapi"
        }
      rescue Connectors::Error => e
        { connected: false, logged_in: false, instance: session_name, provider: "wuzapi", error: e.message }
      end

      def get_qr_code
        result = api_get("/session/qr")
        qr = result.dig("data", "QRCode")
        raise Connectors::Error, "No QR code available" unless qr.present?
        {
          qr_code: qr,
          instance: session_name
        }
      end

      def create_instance(params)
        name = params[:instance_name] || session_name
        webhook_url = params[:webhook_url] || credentials[:webhook_url] || ENV["NEXUS_WEBHOOK_URL"]

        # api_key is the unique per-instance token, set by the controller before credentials are stored
        user_token = api_key

        # WuzAPI: create user via admin API
        admin_token = ENV.fetch("WUZAPI_ADMIN_TOKEN", "brainzlab_admin_dev_key")
        begin
          admin_post("/admin/users", {
            name: name,
            token: user_token,
            webhook: webhook_url || "",
            events: "Message,ReadReceipt"
          }, admin_token)
        rescue Connectors::Error => e
          Rails.logger.info "[WhatsApp/WuzAPI] User may already exist: #{e.message}"
        end

        # Connect the session (Immediate: true to avoid 10s wait)
        result = api_post("/session/connect", {
          Subscribe: ["Message", "ReadReceipt"],
          Immediate: true
        })

        {
          instance_name: name,
          status: result.dig("data", "details") || "created",
          provider: "wuzapi"
        }
      end

      def logout_instance
        api_post("/session/logout", {}) rescue nil
        { success: true, instance: session_name, action: "logout" }
      end

      def delete_instance
        # Step 1: Logout from WhatsApp (unlinks device from phone)
        begin
          api_post("/session/logout", {})
          Rails.logger.info "[WhatsApp/WuzAPI] Session logged out from WhatsApp"
        rescue => e
          Rails.logger.warn "[WhatsApp/WuzAPI] Logout failed: #{e.message}"
        end

        # Step 2: Disconnect session
        begin
          api_post("/session/disconnect", {})
          Rails.logger.info "[WhatsApp/WuzAPI] Session disconnected"
        rescue => e
          Rails.logger.warn "[WhatsApp/WuzAPI] Disconnect failed: #{e.message}"
        end

        # Step 3: Delete user from WuzAPI via admin API
        admin_token = ENV.fetch("WUZAPI_ADMIN_TOKEN", "brainzlab_admin_dev_key")
        begin
          response = http_client.get("/admin/users") do |req|
            req.headers["Authorization"] = admin_token
          end
          users = (JSON.parse(response.body)["data"] rescue []) || []
          user = users.find { |u| u["token"] == api_key || u["name"] == session_name }
          if user
            http_client.delete("/admin/users/#{user['id']}") do |req|
              req.headers["Authorization"] = admin_token
            end
            Rails.logger.info "[WhatsApp/WuzAPI] User #{user['name']} deleted from WuzAPI"
          end
        rescue => e
          Rails.logger.warn "[WhatsApp/WuzAPI] Admin cleanup failed: #{e.message}"
        end

        { success: true, instance: session_name, action: "deleted" }
      end

      # ==================== HTTP Helpers ====================

      def api_get(path)
        response = http_client.get(path) do |req|
          req.headers["Token"] = api_key
        end
        handle_response(response)
      end

      def api_post(path, body)
        response = http_client.post(path) do |req|
          req.headers["Token"] = api_key
          req.headers["Content-Type"] = "application/json"
          req.body = body.to_json
        end
        handle_response(response)
      end

      def admin_post(path, body, token)
        response = http_client.post(path) do |req|
          req.headers["Authorization"] = token
          req.headers["Content-Type"] = "application/json"
          req.body = body.to_json
        end
        handle_response(response)
      end

      def http_client
        @http_client ||= Faraday.new(url: api_url) do |f|
          f.options.timeout = 15
          f.options.open_timeout = 5
        end
      end

      def handle_response(response)
        body = response.body.present? ? JSON.parse(response.body) : {}

        case response.status
        when 200..299
          body
        when 401, 403
          raise Connectors::AuthenticationError, "WhatsApp API auth failed: #{body["error"] || response.status}"
        when 404
          raise Connectors::Error, "WhatsApp API not found: #{body["error"] || "endpoint not found"}"
        when 429
          raise Connectors::RateLimitError, "WhatsApp API rate limited"
        else
          raise Connectors::Error, "WhatsApp API error (#{response.status}): #{body["error"] || body["message"] || "unknown"}"
        end
      rescue JSON::ParserError
        raise Connectors::Error, "Invalid response from WhatsApp API: #{response.body&.truncate(200)}"
      end

      def normalize_phone(phone)
        phone.to_s.gsub(/\D/, "")
      end
    end
  end
end
