module Mcp
  module Tools
    class SshListServerKeys < Base
      DESCRIPTION = "List all SSH server keys (known hosts) stored in the vault."
      INPUT_SCHEMA = {
        type: "object",
        properties: {
          hostname: {
            type: "string",
            description: "Optional filter by hostname"
          },
          trusted_only: {
            type: "boolean",
            description: "Only return trusted keys (default: false)"
          },
          include_archived: {
            type: "boolean",
            description: "Include archived keys (default: false)"
          }
        },
        required: []
      }.freeze

      def call(params)
        keys = project.ssh_server_keys

        # Filter by archived status
        keys = params[:include_archived] ? keys : keys.active

        # Filter by trusted status
        keys = keys.trusted if params[:trusted_only]

        # Filter by hostname
        if params[:hostname].present?
          keys = keys.where("hostname ILIKE ?", "%#{params[:hostname]}%")
        end

        keys = keys.order(hostname: :asc, port: :asc)

        log_access(
          action: "mcp_list_ssh_server_keys",
          details: { count: keys.count, hostname: params[:hostname] }
        )

        success(
          keys: keys.map(&:to_summary),
          count: keys.count
        )
      end
    end
  end
end
