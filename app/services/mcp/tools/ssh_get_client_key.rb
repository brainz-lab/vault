module Mcp
  module Tools
    class SshGetClientKey < Base
      DESCRIPTION = "Retrieve an SSH client key including the decrypted private key."
      INPUT_SCHEMA = {
        type: "object",
        properties: {
          name: {
            type: "string",
            description: "The name of the SSH client key to retrieve"
          }
        },
        required: [ "name" ]
      }.freeze

      def call(params)
        name = params[:name]
        return error("name is required") unless name.present?

        key = project.ssh_client_keys.active.find_by(name: name)
        return error("SSH client key not found: #{name}") unless key

        log_access(
          action: "mcp_get_ssh_client_key",
          details: { name: name, fingerprint: key.fingerprint }
        )

        success(
          name: key.name,
          key_type: key.key_type,
          fingerprint: key.fingerprint,
          key_bits: key.key_bits,
          public_key: key.public_key,
          private_key: key.decrypt_private_key,
          passphrase: key.decrypt_passphrase,
          has_passphrase: key.has_passphrase?,
          comment: key.comment,
          metadata: key.metadata,
          created_at: key.created_at.iso8601
        )
      rescue Encryption::Encryptor::DecryptionError => e
        error("Failed to decrypt key: #{e.message}")
      end
    end
  end
end
