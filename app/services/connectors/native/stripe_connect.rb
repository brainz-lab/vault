# frozen_string_literal: true

module Connectors
  module Native
    class StripeConnect < Base
      def self.piece_name = "stripe"
      def self.display_name = "Stripe"
      def self.description = "Manage payments, customers, and subscriptions via Stripe Connect OAuth"
      def self.category = "payment_processing"
      def self.logo_url = "https://cdn.brainzlab.ai/connectors/stripe.svg"
      def self.auth_type = "OAUTH2"

      def self.auth_schema
        {
          type: "OAUTH2",
          authUrl: "https://connect.stripe.com/oauth/authorize",
          tokenUrl: "https://connect.stripe.com/oauth/token",
          scope: "read_write",
          pkce: false
        }
      end

      def self.setup_guide
        {
          steps: [
            "Go to https://dashboard.stripe.com/settings/connect",
            "Platform settings > Redirect URIs: {VAULT_URL}/oauth/callback",
            "Copy platform Client ID (starts with ca_)",
            "Use your Stripe API secret key as client_secret",
            "Set ENV: VAULT_OAUTH_STRIPE_CLIENT_ID and VAULT_OAUTH_STRIPE_CLIENT_SECRET"
          ],
          docs_url: "https://docs.stripe.com/connect/oauth-reference"
        }
      end

      def self.actions
        [
          { "name" => "list_customers", "displayName" => "List Customers", "description" => "List Stripe customers",
            "props" => { "limit" => { "type" => "number", "required" => false } } },
          { "name" => "create_customer", "displayName" => "Create Customer", "description" => "Create a new Stripe customer",
            "props" => { "email" => { "type" => "string", "required" => true }, "name" => { "type" => "string", "required" => false },
              "description" => { "type" => "string", "required" => false } } },
          { "name" => "list_charges", "displayName" => "List Charges", "description" => "List recent charges",
            "props" => { "limit" => { "type" => "number", "required" => false } } },
          { "name" => "get_balance", "displayName" => "Get Balance", "description" => "Get account balance", "props" => {} }
        ]
      end

      API = "https://api.stripe.com/v1"

      def execute(action, **params)
        case action.to_s
        when "list_customers" then api_get("/customers?limit=#{params[:limit] || 20}")
        when "create_customer" then api_form_post("/customers", params.slice(:email, :name, :description).compact)
        when "list_charges" then api_get("/charges?limit=#{params[:limit] || 20}")
        when "get_balance" then api_get("/balance")
        else raise Connectors::ActionNotFoundError, "Unknown Stripe action: #{action}"
        end
      end

      private

      def access_token = credentials[:access_token] || credentials[:stripe_user_id] || raise(Connectors::AuthenticationError, "No access token")

      def api_get(path)
        resp = faraday.get("#{API}#{path}") { |r| r.headers["Authorization"] = "Bearer #{access_token}" }
        handle(resp)
      end

      def api_form_post(path, params)
        resp = faraday.post("#{API}#{path}") do |r|
          r.headers["Authorization"] = "Bearer #{access_token}"
          r.headers["Content-Type"] = "application/x-www-form-urlencoded"
          r.body = URI.encode_www_form(params)
        end
        handle(resp)
      end

      def handle(resp)
        raise Connectors::AuthenticationError, "Stripe: unauthorized" if resp.status == 401
        data = JSON.parse(resp.body)
        raise Connectors::Error, "Stripe API error: #{data.dig('error', 'message')}" if data["error"]
        data
      end

      def faraday = @faraday ||= Faraday.new { |f| f.options.timeout = 15; f.options.open_timeout = 5 }
    end
  end
end
