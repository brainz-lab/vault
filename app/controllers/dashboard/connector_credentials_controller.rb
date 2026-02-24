module Dashboard
  class ConnectorCredentialsController < BaseController
    before_action :require_project!
    before_action :set_credential, only: [ :destroy, :verify ]

    def index
      @credentials = current_project.connector_credentials
                                    .includes(:connector)
                                    .order(created_at: :desc)
    end

    def new
      @connector = Connector.find(params[:connector_id]) if params[:connector_id]
      @connectors = Connector.enabled.where.not(auth_type: [ nil, "NONE" ]).order(:display_name)
    end

    def create
      connector = Connector.find(credential_params[:connector_id])

      credentials = build_credentials_hash(connector)

      @credential = ConnectorCredential.create_encrypted(
        project: current_project,
        connector: connector,
        name: credential_params[:name],
        auth_type: connector.auth_type,
        credentials: credentials
      )

      redirect_to dashboard_project_connector_credentials_path(current_project),
                  notice: "Credential stored for #{connector.display_name}"
    rescue ActiveRecord::RecordInvalid => e
      @connector = connector
      @connectors = Connector.enabled.where.not(auth_type: [ nil, "NONE" ]).order(:display_name)
      flash.now[:alert] = e.record.errors.full_messages.join(", ")
      render :new, status: :unprocessable_entity
    end

    def destroy
      connector_name = @credential.connector.display_name
      @credential.revoke!
      redirect_to dashboard_project_connector_credentials_path(current_project),
                  notice: "Credential for #{connector_name} revoked"
    end

    def verify
      begin
        @credential.mark_verified!
        redirect_to dashboard_project_connector_credentials_path(current_project),
                    notice: "Credential verified successfully"
      rescue => e
        @credential.mark_error!(e.message)
        redirect_to dashboard_project_connector_credentials_path(current_project),
                    alert: "Verification failed: #{e.message}"
      end
    end

    private

    def set_credential
      @credential = current_project.connector_credentials.find(params[:id])
    end

    def credential_params
      params.require(:connector_credential).permit(:connector_id, :name)
    end

    def build_credentials_hash(connector)
      creds = {}
      case connector.auth_type
      when "SECRET_TEXT"
        creds[:token] = params.dig(:credentials, :token)
      when "BASIC"
        creds[:username] = params.dig(:credentials, :username)
        creds[:password] = params.dig(:credentials, :password)
      when "CUSTOM_AUTH"
        # Build from auth_schema fields
        (connector.auth_schema || {}).each do |key, _config|
          creds[key.to_sym] = params.dig(:credentials, key)
        end
      when "OAUTH2"
        creds[:access_token] = params.dig(:credentials, :access_token)
        creds[:refresh_token] = params.dig(:credentials, :refresh_token)
      end
      creds
    end
  end
end
