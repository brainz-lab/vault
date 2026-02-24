module Mcp
  module Tools
    class ConnectorListConnections < Base
      DESCRIPTION = "List the current project's connected connectors."
      INPUT_SCHEMA = {
        type: "object",
        properties: {
          status: { type: "string", enum: %w[connected disconnected error], description: "Filter by status" },
          active_only: { type: "boolean", description: "Only show active/enabled connections (default: true)" }
        },
        required: []
      }.freeze

      def call(params)
        connections = project.connector_connections.includes(:connector)

        if params[:active_only] != false
          connections = connections.active
        end
        connections = connections.where(status: params[:status]) if params[:status].present?

        log_access(action: "mcp_connector_list_connections")

        success(
          connections: connections.map(&:to_summary),
          total: connections.size
        )
      end
    end
  end
end
