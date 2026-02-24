module Mcp
  module Tools
    class ConnectorDetail < Base
      DESCRIPTION = "Get full detail for a connector including all actions, auth schema, and triggers."
      INPUT_SCHEMA = {
        type: "object",
        properties: {
          piece_name: { type: "string", description: "The connector piece name (e.g. 'slack', 'webhook')" }
        },
        required: [ "piece_name" ]
      }.freeze

      def call(params)
        piece_name = params[:piece_name]
        return error("piece_name is required") unless piece_name.present?

        connector = Connector.enabled.find_by(piece_name: piece_name)
        return error("Connector not found: #{piece_name}") unless connector

        log_access(action: "mcp_connector_detail", details: { piece_name: piece_name })

        success(connector.to_detail)
      end
    end
  end
end
