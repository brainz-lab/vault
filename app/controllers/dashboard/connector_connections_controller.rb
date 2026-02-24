module Dashboard
  class ConnectorConnectionsController < BaseController
    before_action :require_project!
    before_action :set_connection, only: [ :show, :destroy, :test, :execute ]

    def index
      @connections = current_project.connector_connections
                                    .includes(:connector, :connector_credential)
                                    .order(created_at: :desc)
    end

    def new
      @connectors = Connector.enabled.order(:display_name)
      @credentials = current_project.connector_credentials.active.includes(:connector)
    end

    def create
      connector = Connector.find(connection_params[:connector_id])
      credential = connection_params[:connector_credential_id].present? ?
        current_project.connector_credentials.find(connection_params[:connector_credential_id]) : nil

      @connection = current_project.connector_connections.create!(
        connector: connector,
        connector_credential: credential,
        name: connection_params[:name].presence || "#{connector.display_name} Connection",
        config: parse_config,
        status: "connected",
        enabled: true
      )

      redirect_to dashboard_project_connector_connection_path(current_project, @connection),
                  notice: "Connected to #{connector.display_name}"
    rescue ActiveRecord::RecordInvalid => e
      @connectors = Connector.enabled.order(:display_name)
      @credentials = current_project.connector_credentials.active.includes(:connector)
      flash.now[:alert] = e.record.errors.full_messages.join(", ")
      render :new, status: :unprocessable_entity
    end

    def show
      @connector = @connection.connector
      @actions = @connector.actions || []
      @recent_executions = @connection.connector_executions.recent.limit(20)
    end

    def destroy
      connector_name = @connection.connector.display_name
      @connection.disconnect!
      redirect_to dashboard_project_connector_connections_path(current_project),
                  notice: "Disconnected from #{connector_name}"
    end

    def test
      begin
        @connection.mark_connected!
        redirect_to dashboard_project_connector_connection_path(current_project, @connection),
                    notice: "Connection test successful"
      rescue => e
        @connection.mark_error!(e.message)
        redirect_to dashboard_project_connector_connection_path(current_project, @connection),
                    alert: "Connection test failed: #{e.message}"
      end
    end

    def execute
      action_name = params[:action_name]
      input = params[:input]&.permit!&.to_h || {}

      executor = Connectors::Executor.new(
        project: current_project,
        caller_service: "dashboard",
        caller_request_id: request.request_id
      )

      @result = executor.execute(
        connection_id: @connection.id,
        action_name: action_name,
        input: input
      )

      @connector = @connection.connector
      @actions = @connector.actions || []
      @recent_executions = @connection.connector_executions.recent.limit(20)

      flash.now[:notice] = "Action '#{action_name}' executed successfully"
      render :show
    rescue Connectors::Error => e
      @connector = @connection.connector
      @actions = @connector.actions || []
      @recent_executions = @connection.connector_executions.recent.limit(20)

      @error = e.message
      flash.now[:alert] = "Execution failed: #{e.message}"
      render :show
    end

    private

    def set_connection
      @connection = current_project.connector_connections.find(params[:id])
    end

    def connection_params
      params.require(:connector_connection).permit(:connector_id, :connector_credential_id, :name)
    end

    def parse_config
      return {} unless params[:config_json].present?
      JSON.parse(params[:config_json])
    rescue JSON::ParserError
      {}
    end
  end
end
