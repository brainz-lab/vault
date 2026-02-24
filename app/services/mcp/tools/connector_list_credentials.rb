module Mcp
  module Tools
    class ConnectorListCredentials < Base
      DESCRIPTION = "List the current project's stored connector credentials."
      INPUT_SCHEMA = {
        type: "object",
        properties: {
          piece_name: { type: "string", description: "Filter by connector piece name" },
          status: { type: "string", enum: %w[active expired error revoked], description: "Filter by status" }
        },
        required: []
      }.freeze

      def call(params)
        credentials = project.connector_credentials.includes(:connector)

        if params[:piece_name].present?
          connector = Connector.find_by(piece_name: params[:piece_name])
          credentials = credentials.for_connector(connector) if connector
        end

        credentials = credentials.where(status: params[:status]) if params[:status].present?

        log_access(action: "mcp_connector_list_credentials")

        success(
          credentials: credentials.map(&:to_summary),
          total: credentials.size
        )
      end
    end
  end
end
