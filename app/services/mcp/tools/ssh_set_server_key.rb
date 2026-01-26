module Mcp
  module Tools
    class SshSetServerKey < Base
      DESCRIPTION = "Add or update an SSH server key (known host) in the vault."
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
            description: "The key type (e.g., ssh-rsa, ssh-ed25519, ecdsa-sha2-nistp256)"
          },
          public_key: {
            type: "string",
            description: "The server's public key (base64 encoded part only, or full line)"
          },
          trusted: {
            type: "boolean",
            description: "Whether this key is trusted (default: true)"
          },
          comment: {
            type: "string",
            description: "Optional comment about this server key"
          },
          metadata: {
            type: "object",
            description: "Optional metadata to attach to the key"
          }
        },
        required: [ "hostname", "key_type", "public_key" ]
      }.freeze

      def call(params)
        hostname = params[:hostname]
        port = params[:port] || 22
        key_type = params[:key_type]
        public_key = params[:public_key]

        return error("hostname is required") unless hostname.present?
        return error("key_type is required") unless key_type.present?
        return error("public_key is required") unless public_key.present?

        # Parse public key if it's a full line
        if public_key.include?(" ")
          parts = public_key.strip.split(" ")
          key_type = parts[0] if parts[0] != key_type
          public_key = parts[1]
        end

        # Calculate fingerprint
        full_key = "#{key_type} #{public_key}"
        fingerprint = Ssh::KeyGenerator.fingerprint(full_key)

        # Check for existing key with same host/port/type
        existing = project.ssh_server_keys.active.find_by(
          hostname: hostname,
          port: port,
          key_type: key_type
        )

        if existing
          # Update existing key
          existing.update!(
            public_key: public_key,
            fingerprint: fingerprint,
            trusted: params.fetch(:trusted, existing.trusted),
            comment: params[:comment] || existing.comment,
            metadata: (existing.metadata || {}).merge(params[:metadata] || {}),
            verified_at: Time.current
          )

          log_access(
            action: "mcp_update_ssh_server_key",
            details: { hostname: hostname, port: port, fingerprint: fingerprint }
          )

          success(existing.to_summary.merge(updated: true, created: false))
        else
          # Create new key
          key = project.ssh_server_keys.create!(
            hostname: hostname,
            port: port,
            key_type: key_type,
            public_key: public_key,
            fingerprint: fingerprint,
            trusted: params.fetch(:trusted, true),
            verified_at: Time.current,
            comment: params[:comment],
            metadata: params[:metadata] || {}
          )

          log_access(
            action: "mcp_create_ssh_server_key",
            details: { hostname: hostname, port: port, fingerprint: fingerprint }
          )

          success(key.to_summary.merge(updated: false, created: true))
        end
      rescue ActiveRecord::RecordInvalid => e
        error("Failed to save server key: #{e.message}")
      end
    end
  end
end
