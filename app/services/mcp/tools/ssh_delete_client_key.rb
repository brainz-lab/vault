module Mcp
  module Tools
    class SshDeleteClientKey < Base
      DESCRIPTION = "Archive (soft-delete) an SSH client key from the vault."
      INPUT_SCHEMA = {
        type: "object",
        properties: {
          name: {
            type: "string",
            description: "The name of the SSH client key to delete"
          },
          permanent: {
            type: "boolean",
            description: "Permanently delete instead of archiving (default: false)"
          }
        },
        required: [ "name" ]
      }.freeze

      def call(params)
        name = params[:name]
        return error("name is required") unless name.present?

        key = project.ssh_client_keys.find_by(name: name)
        return error("SSH client key not found: #{name}") unless key

        if key.archived?
          return error("SSH client key is already archived: #{name}")
        end

        fingerprint = key.fingerprint

        if params[:permanent]
          # Check for dependent connections
          if key.ssh_connections.any?
            return error("Cannot permanently delete key with #{key.ssh_connections.count} associated connection(s). Remove connections first or use archive.")
          end
          key.destroy!
          action = "mcp_permanently_delete_ssh_client_key"
        else
          key.archive!
          action = "mcp_archive_ssh_client_key"
        end

        log_access(
          action: action,
          details: { name: name, fingerprint: fingerprint }
        )

        success(
          name: name,
          fingerprint: fingerprint,
          archived: !params[:permanent],
          deleted: params[:permanent] || false
        )
      end
    end
  end
end
