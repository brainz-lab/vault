module Mcp
  module Tools
    class SshGetServerKey < Base
      DESCRIPTION = "Retrieve an SSH server key (known host) by hostname and port."
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
          }
        },
        required: [ "hostname" ]
      }.freeze

      def call(params)
        hostname = params[:hostname]
        port = params[:port] || 22

        return error("hostname is required") unless hostname.present?

        keys = project.ssh_server_keys.active.by_host(hostname, port)

        if keys.empty?
          return error("No SSH server keys found for #{hostname}:#{port}")
        end

        log_access(
          action: "mcp_get_ssh_server_key",
          details: { hostname: hostname, port: port, count: keys.count }
        )

        success(
          hostname: hostname,
          port: port,
          keys: keys.map(&:to_summary),
          known_hosts_lines: keys.map(&:to_known_hosts_line)
        )
      end
    end
  end
end
