module Mcp
  module Tools
    class ConnectorExecute < Base
      DESCRIPTION = "Execute a connector action. Requires an active connection."
      INPUT_SCHEMA = {
        type: "object",
        properties: {
          connection_id: { type: "string", description: "The connection ID to execute against" },
          piece_name: { type: "string", description: "Or find connection by piece name" },
          action_name: { type: "string", description: "The action to execute (e.g. 'send_message')" },
          input: { type: "object", description: "Action input parameters" },
          timeout: { type: "integer", description: "Timeout in milliseconds (default: 30000)" }
        },
        required: [ "action_name" ]
      }.freeze

      def call(params)
        return error("action_name is required") unless params[:action_name].present?

        connection = resolve_connection(params)
        return error("Connection not found or not active") unless connection

        executor = Connectors::Executor.new(
          project: project,
          caller_service: "mcp",
          caller_request_id: SecureRandom.uuid
        )

        result = executor.execute(
          connection_id: connection.id,
          action_name: params[:action_name],
          input: params[:input] || {},
          timeout: (params[:timeout] || 30_000).to_i
        )

        log_access(
          action: "mcp_connector_execute",
          details: { piece_name: connection.connector.piece_name, action: params[:action_name] }
        )

        success(result)
      rescue Connectors::Error => e
        error(e.message)
      end

      private

      def resolve_connection(params)
        if params[:connection_id].present?
          project.connector_connections.connected.find_by(id: params[:connection_id])
        elsif params[:piece_name].present?
          connector = Connector.find_by(piece_name: params[:piece_name])
          project.connector_connections.connected.find_by(connector: connector) if connector
        end
      end
    end
  end
end
