module Api
  module V1
    class ConnectorConnectionsController < BaseController
      before_action :set_connection, only: [ :show, :update, :destroy, :test, :execute ]

      # GET /api/v1/connector_connections
      def index
        connections = current_project.connector_connections.includes(:connector, :connector_credential)

        connections = connections.connected if params[:status] == "connected"
        connections = connections.active if params[:active] == "true"

        render json: {
          connections: connections.map(&:to_summary),
          total: connections.size
        }
      end

      # POST /api/v1/connector_connections
      def create
        return unless require_permission!("write")

        connector = Connector.enabled.find(params[:connector_id])
        credential = params[:credential_id].present? ? current_project.connector_credentials.find(params[:credential_id]) : nil

        connection = current_project.connector_connections.create!(
          connector: connector,
          connector_credential: credential,
          name: params[:name] || connector.display_name,
          config: params[:config] || {},
          status: "connected",
          enabled: true
        )

        log_access(
          action: "create_connector_connection",
          details: { connector: connector.piece_name, connection_name: connection.name }
        )

        render json: { connection: connection.to_detail }, status: :created
      end

      # GET /api/v1/connector_connections/:id
      def show
        render json: { connection: @connection.to_detail }
      end

      # PUT /api/v1/connector_connections/:id
      def update
        return unless require_permission!("write")

        attrs = {}
        attrs[:name] = params[:name] if params.key?(:name)
        attrs[:config] = params[:config] if params.key?(:config)
        attrs[:enabled] = params[:enabled] if params.key?(:enabled)
        attrs[:connector_credential_id] = params[:credential_id] if params.key?(:credential_id)

        @connection.update!(attrs)

        render json: { connection: @connection.reload.to_detail }
      end

      # DELETE /api/v1/connector_connections/:id
      def destroy
        return unless require_permission!("write")

        @connection.disconnect!

        log_access(
          action: "disconnect_connector",
          details: { connector: @connection.connector.piece_name }
        )

        render json: { success: true }
      end

      # POST /api/v1/connector_connections/:id/test
      def test
        connector = @connection.connector
        credential = @connection.connector_credential

        if credential.present?
          credentials = credential.decrypt_credentials

          if connector.native?
            # Actually test native connectors by calling their test_connection action
            runner_class = Connectors::Executor.new(
              project: current_project,
              caller_service: "test"
            )
            result = runner_class.execute(
              connection_id: @connection.id,
              action_name: "test_connection",
              input: {}
            )

            @connection.mark_connected!
            credential.mark_verified!
            render json: { success: true, status: "connected", details: result[:output] }
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
              @connection.mark_connected!
              credential.mark_verified!
              render json: { success: true, status: "connected" }
            else
              @connection.mark_error!(response.body["error"] || "Test failed")
              render json: { success: false, error: response.body["error"] }
            end
          else
            @connection.mark_connected!
            credential.mark_verified!
            render json: { success: true, status: "connected" }
          end
        else
          @connection.mark_connected!
          render json: { success: true, status: "connected" }
        end
      rescue Connectors::AuthenticationError => e
        @connection.mark_error!(e.message)
        credential&.mark_error!(e.message)
        render json: { success: false, error: e.message }
      rescue Connectors::Error => e
        @connection.mark_error!(e.message)
        render json: { success: false, error: e.message }
      rescue Faraday::Error => e
        @connection.mark_error!("Sidecar unavailable")
        render json: { success: false, error: "Sidecar unavailable: #{e.message}" }
      end

      # POST /api/v1/connector_connections/:id/execute
      def execute
        return unless require_permission!("write")

        executor = Connectors::Executor.new(
          project: current_project,
          caller_service: request.headers["X-Caller-Service"] || "api",
          caller_request_id: request.request_id
        )

        result = executor.execute(
          connection_id: @connection.id,
          action_name: params[:action_name],
          input: params[:input]&.to_unsafe_h || {},
          timeout: (params[:timeout] || 30_000).to_i
        )

        log_access(
          action: "execute_connector",
          details: { connector: @connection.connector.piece_name, action: params[:action_name] }
        )

        render json: result
      rescue Connectors::Error => e
        render json: { success: false, error: e.message }, status: :unprocessable_entity
      end

      # GET /api/v1/connector_connections/mcp_tools
      def mcp_tools
        connections = current_project.connector_connections.connected.includes(:connector)

        tools = connections.flat_map do |conn|
          (conn.connector.actions || []).map do |action|
            {
              name: "#{conn.connector.piece_name}__#{action['name']}",
              description: action["description"] || action["displayName"],
              connection_id: conn.id,
              input_schema: {
                type: "object",
                properties: (action["props"] || {}).transform_values { |v| v.slice("type", "description") }
              }
            }
          end
        end

        render json: { tools: tools, total: tools.size }
      end

      private

      def set_connection
        @connection = current_project.connector_connections.find(params[:id])
      end
    end
  end
end
