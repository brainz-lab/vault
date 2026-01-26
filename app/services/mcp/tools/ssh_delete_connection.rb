module Mcp
  module Tools
    class SshDeleteConnection < Base
      DESCRIPTION = "Archive (soft-delete) an SSH connection profile from the vault."
      INPUT_SCHEMA = {
        type: "object",
        properties: {
          name: {
            type: "string",
            description: "The name of the SSH connection to delete"
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

        connection = project.ssh_connections.find_by(name: name)
        return error("SSH connection not found: #{name}") unless connection

        if connection.archived?
          return error("SSH connection is already archived: #{name}")
        end

        host = connection.host

        if params[:permanent]
          # Check for dependent connections
          if connection.dependent_connections.any?
            return error("Cannot permanently delete connection with #{connection.dependent_connections.count} dependent connection(s) using it as jump host. Remove dependencies first or use archive.")
          end
          connection.destroy!
          action = "mcp_permanently_delete_ssh_connection"
        else
          connection.archive!
          action = "mcp_archive_ssh_connection"
        end

        log_access(
          action: action,
          details: { name: name, host: host }
        )

        success(
          name: name,
          host: host,
          archived: !params[:permanent],
          deleted: params[:permanent] || false
        )
      end
    end
  end
end
