module Mcp
  module Tools
    class SshDeleteServerKey < Base
      DESCRIPTION = "Archive (soft-delete) an SSH server key from the vault."
      INPUT_SCHEMA = {
        type: "object",
        properties: {
          hostname: {
            type: "string",
            description: "The server hostname"
          },
          port: {
            type: "integer",
            description: "The SSH port (default: 22)"
          },
          key_type: {
            type: "string",
            description: "Optional key type to delete specific key (otherwise all keys for host:port)"
          },
          permanent: {
            type: "boolean",
            description: "Permanently delete instead of archiving (default: false)"
          }
        },
        required: [ "hostname" ]
      }.freeze

      def call(params)
        hostname = params[:hostname]
        port = params[:port] || 22

        return error("hostname is required") unless hostname.present?

        keys = project.ssh_server_keys.active.by_host(hostname, port)

        if params[:key_type].present?
          keys = keys.where(key_type: params[:key_type])
        end

        if keys.empty?
          return error("No SSH server keys found for #{hostname}:#{port}")
        end

        deleted_count = 0
        fingerprints = []

        keys.each do |key|
          fingerprints << key.fingerprint
          if params[:permanent]
            key.destroy!
          else
            key.archive!
          end
          deleted_count += 1
        end

        action = params[:permanent] ? "mcp_permanently_delete_ssh_server_key" : "mcp_archive_ssh_server_key"

        log_access(
          action: action,
          details: {
            hostname: hostname,
            port: port,
            count: deleted_count,
            fingerprints: fingerprints
          }
        )

        success(
          hostname: hostname,
          port: port,
          count: deleted_count,
          archived: !params[:permanent],
          deleted: params[:permanent] || false
        )
      end
    end
  end
end
