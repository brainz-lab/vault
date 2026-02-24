module Mcp
  module Tools
    class ConnectorDisconnect < Base
      DESCRIPTION = "Disconnect a connector from the current project."
      INPUT_SCHEMA = {
        type: "object",
        properties: {
          connection_id: { type: "string", description: "The connection ID to disconnect" },
          piece_name: { type: "string", description: "Or disconnect by piece name" }
        },
        required: []
      }.freeze

      def call(params)
        connection = if params[:connection_id].present?
          project.connector_connections.find_by(id: params[:connection_id])
        elsif params[:piece_name].present?
          connector = Connector.find_by(piece_name: params[:piece_name])
          project.connector_connections.active.find_by(connector: connector) if connector
        end

        return error("Connection not found") unless connection

        connection.disconnect!

        log_access(action: "mcp_connector_disconnect", details: { piece_name: connection.connector.piece_name })

        success(disconnected: true, piece_name: connection.connector.piece_name)
      end
    end
  end
end
