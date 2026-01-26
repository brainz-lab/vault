module Mcp
  module Tools
    class SshListConnections < Base
      DESCRIPTION = "List all SSH connection profiles stored in the vault."
      INPUT_SCHEMA = {
        type: "object",
        properties: {
          host: {
            type: "string",
            description: "Optional filter by host"
          },
          include_archived: {
            type: "boolean",
            description: "Include archived connections (default: false)"
          }
        },
        required: []
      }.freeze

      def call(params)
        connections = project.ssh_connections

        # Filter by archived status
        connections = params[:include_archived] ? connections : connections.active

        # Filter by host
        if params[:host].present?
          connections = connections.where("host ILIKE ?", "%#{params[:host]}%")
        end

        connections = connections.order(name: :asc)

        log_access(
          action: "mcp_list_ssh_connections",
          details: { count: connections.count, host: params[:host] }
        )

        success(
          connections: connections.map(&:to_summary),
          count: connections.count
        )
      end
    end
  end
end
