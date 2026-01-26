module Mcp
  module Tools
    class SshSetConnection < Base
      DESCRIPTION = "Create or update an SSH connection profile in the vault."
      INPUT_SCHEMA = {
        type: "object",
        properties: {
          name: {
            type: "string",
            description: "A unique name for the connection"
          },
          host: {
            type: "string",
            description: "The server hostname or IP address"
          },
          port: {
            type: "integer",
            description: "The SSH port (default: 22)"
          },
          username: {
            type: "string",
            description: "The SSH username"
          },
          client_key_name: {
            type: "string",
            description: "Optional name of the SSH client key to use"
          },
          jump_connection_name: {
            type: "string",
            description: "Optional name of a jump/bastion connection to use"
          },
          description: {
            type: "string",
            description: "Optional description of the connection"
          },
          options: {
            type: "object",
            description: "Optional SSH options (e.g., ForwardAgent, ServerAliveInterval)"
          },
          metadata: {
            type: "object",
            description: "Optional metadata to attach to the connection"
          }
        },
        required: [ "name", "host", "username" ]
      }.freeze

      def call(params)
        name = params[:name]
        host = params[:host]
        username = params[:username]
        port = params[:port] || 22

        return error("name is required") unless name.present?
        return error("host is required") unless host.present?
        return error("username is required") unless username.present?

        # Resolve client key if specified
        client_key = nil
        if params[:client_key_name].present?
          client_key = project.ssh_client_keys.active.find_by(name: params[:client_key_name])
          return error("SSH client key not found: #{params[:client_key_name]}") unless client_key
        end

        # Resolve jump connection if specified
        jump_connection = nil
        if params[:jump_connection_name].present?
          jump_connection = project.ssh_connections.active.find_by(name: params[:jump_connection_name])
          return error("Jump connection not found: #{params[:jump_connection_name]}") unless jump_connection
        end

        # Check for existing connection
        existing = project.ssh_connections.active.find_by(name: name)

        if existing
          # Update existing connection
          existing.update!(
            host: host,
            port: port,
            username: username,
            ssh_client_key: client_key,
            jump_connection: jump_connection,
            description: params[:description] || existing.description,
            options: params[:options] || existing.options,
            metadata: (existing.metadata || {}).merge(params[:metadata] || {})
          )

          log_access(
            action: "mcp_update_ssh_connection",
            details: { name: name, host: host, updated: true }
          )

          success(existing.to_summary.merge(updated: true, created: false))
        else
          # Create new connection
          connection = project.ssh_connections.create!(
            name: name,
            host: host,
            port: port,
            username: username,
            ssh_client_key: client_key,
            jump_connection: jump_connection,
            description: params[:description],
            options: params[:options] || {},
            metadata: params[:metadata] || {}
          )

          log_access(
            action: "mcp_create_ssh_connection",
            details: { name: name, host: host, created: true }
          )

          success(connection.to_summary.merge(updated: false, created: true))
        end
      rescue ActiveRecord::RecordInvalid => e
        error("Failed to save connection: #{e.message}")
      end
    end
  end
end
