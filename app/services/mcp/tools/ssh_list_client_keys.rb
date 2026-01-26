module Mcp
  module Tools
    class SshListClientKeys < Base
      DESCRIPTION = "List all SSH client keys (identity keys) stored in the vault."
      INPUT_SCHEMA = {
        type: "object",
        properties: {
          key_type: {
            type: "string",
            enum: [ "rsa-2048", "rsa-4096", "ed25519" ],
            description: "Optional filter by key type"
          },
          include_archived: {
            type: "boolean",
            description: "Include archived keys (default: false)"
          }
        },
        required: []
      }.freeze

      def call(params)
        keys = project.ssh_client_keys

        # Filter by archived status
        keys = params[:include_archived] ? keys : keys.active

        # Filter by key type
        if params[:key_type].present?
          keys = keys.by_type(params[:key_type])
        end

        keys = keys.order(created_at: :desc)

        log_access(
          action: "mcp_list_ssh_client_keys",
          details: { count: keys.count, key_type: params[:key_type] }
        )

        success(
          keys: keys.map(&:to_summary),
          count: keys.count
        )
      end
    end
  end
end
