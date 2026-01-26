module Mcp
  module Tools
    class SshGetConnection < Base
      DESCRIPTION = "Retrieve an SSH connection profile with resolved key details."
      INPUT_SCHEMA = {
        type: "object",
        properties: {
          name: {
            type: "string",
            description: "The name of the SSH connection to retrieve"
          },
          include_private_key: {
            type: "boolean",
            description: "Include the decrypted private key (default: true)"
          }
        },
        required: [ "name" ]
      }.freeze

      def call(params)
        name = params[:name]
        include_private_key = params.fetch(:include_private_key, true)

        return error("name is required") unless name.present?

        connection = project.ssh_connections.active.find_by(name: name)
        return error("SSH connection not found: #{name}") unless connection

        log_access(
          action: "mcp_get_ssh_connection",
          details: { name: name, host: connection.host }
        )

        if include_private_key
          success(connection.to_full_details)
        else
          success(connection.to_summary)
        end
      rescue Encryption::Encryptor::DecryptionError => e
        error("Failed to decrypt key: #{e.message}")
      end
    end
  end
end
