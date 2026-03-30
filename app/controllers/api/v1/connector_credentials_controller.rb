module Api
  module V1
    class ConnectorCredentialsController < BaseController
      before_action :require_project!
      before_action :set_credential, only: [ :show, :destroy, :verify ]

      # GET /api/v1/connector_credentials
      def index
        credentials = current_project.connector_credentials.includes(:connector)

        credentials = credentials.for_connector(Connector.find(params[:connector_id])) if params[:connector_id].present?
        credentials = credentials.active if params[:status] == "active"

        render json: {
          credentials: credentials.map(&:to_summary),
          total: credentials.size
        }
      end

      # POST /api/v1/connector_credentials
      def create
        return unless require_permission!("write")

        connector = Connector.enabled.find(params[:connector_id])

        credential = ConnectorCredential.create_encrypted(
          project: current_project,
          connector: connector,
          name: params[:name],
          auth_type: params[:auth_type] || connector.auth_type || "SECRET_TEXT",
          credentials: credential_values
        )

        log_access(
          action: "create_connector_credential",
          details: { connector: connector.piece_name, credential_name: params[:name] }
        )

        render json: { credential: credential.to_summary }, status: :created
      end

      # GET /api/v1/connector_credentials/:id
      def show
        render json: { credential: @credential.to_summary }
      end

      # DELETE /api/v1/connector_credentials/:id
      def destroy
        return unless require_permission!("write")

        @credential.revoke!

        log_access(
          action: "revoke_connector_credential",
          details: { credential_name: @credential.name }
        )

        render json: { success: true }
      end

      # POST /api/v1/connector_credentials/:id/verify
      def verify
        connector = @credential.connector
        credentials = @credential.decrypt_credentials

        if connector.native?
          @credential.mark_verified!
          render json: { valid: true }
        elsif connector.activepieces?
          sidecar_url = ENV.fetch("CONNECTOR_SIDECAR_URL", "http://localhost:3100")
          sidecar_key = ENV["CONNECTOR_SIDECAR_SECRET_KEY"]

          response = Faraday.new(url: sidecar_url) do |f|
            f.request :json
            f.response :json
            f.options.timeout = 30
          end.post("/validate") do |req|
            req.headers["Authorization"] = "Bearer #{sidecar_key}" if sidecar_key.present?
            req.body = { piece: connector.piece_name, auth: credentials }
          end

          if response.success? && response.body["valid"]
            @credential.mark_verified!
            render json: { valid: true }
          else
            @credential.mark_error!(response.body["error"] || "Validation failed")
            render json: { valid: false, error: response.body["error"] }
          end
        else
          render json: { valid: false, error: "Unsupported connector type" }
        end
      rescue Faraday::Error => e
        render json: { valid: false, error: "Sidecar unavailable: #{e.message}" }
      end

      private

      def set_credential
        @credential = current_project.connector_credentials.find(params[:id])
      end

      def credential_values
        # If credentials are passed as a nested hash, use them directly
        if params[:credentials].is_a?(ActionController::Parameters) || params[:credentials].is_a?(Hash)
          creds = params[:credentials]
          return creds.respond_to?(:to_unsafe_h) ? creds.to_unsafe_h.compact_blank : creds.to_h.compact_blank
        end

        # Static whitelist for known credential fields
        static_keys = %w[
          value api_key token username password secret
          access_key_id secret_access_key host port database
          smtp_host smtp_port imap_host imap_port from
          bucket region base_path adapter smtp_domain
          domain webhook_token webhook_url auth_method access_token refresh_token
          subdomain api_token email domain_name start_date
        ]

        # Also accept any keys defined in the connector's auth_schema
        dynamic_keys = []
        if params[:connector_id].present?
          connector = Connector.find_by(id: params[:connector_id])
          if connector&.auth_schema.is_a?(Hash)
            # Activepieces format: auth_schema.props
            props = connector.auth_schema["props"] || connector.auth_schema[:props] || {}
            # Airbyte format: auth_schema.properties (JSON Schema)
            properties = connector.auth_schema["properties"] || connector.auth_schema[:properties] || {}
            dynamic_keys = (props.keys + properties.keys).map(&:to_s)
          end
        end

        allowed_keys = (static_keys + dynamic_keys).uniq
        params.permit(*allowed_keys).to_h.compact_blank
      end
    end
  end
end
