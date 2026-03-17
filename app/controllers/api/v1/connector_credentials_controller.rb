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

      # POST /api/v1/connector_credentials/oauth_authorize
      # For connectors where the user provides their own OAuth app credentials
      # (e.g. Salesforce). Creates a pending credential, stores user credentials,
      # and returns an authorize URL that goes through OauthController.
      #
      # For platform-managed OAuth (Slack, GitHub) where client_id/secret are in ENV,
      # redirect directly to GET /oauth/authorize instead.
      def oauth_authorize
        return unless require_permission!("write")

        connector = Connector.enabled.find(params[:connector_id])
        cred_values = credential_values

        unless connector.oauth2?
          render json: { error: "Connector '#{connector.display_name}' does not support OAuth2" }, status: :unprocessable_entity
          return
        end

        # Create or reuse a pending credential to store the user's OAuth app credentials
        cred_name = params[:name] || "#{connector.display_name} OAuth"
        existing = current_project.connector_credentials
          .where(connector: connector, status: "pending")
          .order(created_at: :desc)
          .first

        credential = if existing
          existing.update_credentials(cred_values)
          existing
        else
          cred = ConnectorCredential.create_encrypted(
            project: current_project,
            connector: connector,
            name: "#{cred_name} #{Time.current.to_i}",
            auth_type: "OAUTH2",
            credentials: cred_values
          )
          cred.update_columns(status: "pending")
          cred
        end

        # Build the Vault OAuth authorize URL — credential_id is stored in the state
        # so the callback can retrieve the user's client_id/client_secret
        oauth_params = {
          project_id: current_project.id,
          connector_id: connector.piece_name,
          return_to: params[:return_url].to_s,
          credential_id: credential.id
        }.compact_blank

        authorize_url = "#{vault_external_url}/oauth/authorize?" + URI.encode_www_form(oauth_params)

        render json: {
          authorize_url: authorize_url,
          credential_id: credential.id
        }
      rescue ActiveRecord::RecordInvalid => e
        render json: { error: e.message }, status: :unprocessable_entity
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

      def vault_external_url
        ENV.fetch("VAULT_EXTERNAL_URL") { ENV.fetch("VAULT_URL", "http://localhost:4006") }
      end

      def credential_values
        # Static whitelist for known credential fields
        static_keys = %w[
          value api_key token username password secret
          access_key_id secret_access_key host port database
          smtp_host smtp_port imap_host imap_port from
          bucket region base_path adapter smtp_domain
          domain webhook_token webhook_url auth_method access_token refresh_token
          subdomain api_token
        ]

        # Also accept any keys defined in the connector's auth_schema props
        dynamic_keys = []
        if params[:connector_id].present?
          connector = Connector.find_by(id: params[:connector_id])
          if connector&.auth_schema.is_a?(Hash)
            props = connector.auth_schema["props"] || connector.auth_schema[:props] || {}
            dynamic_keys = props.keys.map(&:to_s)
          end
        end

        allowed_keys = (static_keys + dynamic_keys).uniq
        params.permit(*allowed_keys).to_h.compact_blank
      end
    end
  end
end
