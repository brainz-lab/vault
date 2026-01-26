module Mcp
  module Tools
    class SshSetClientKey < Base
      DESCRIPTION = "Import an existing SSH private key into the vault."
      INPUT_SCHEMA = {
        type: "object",
        properties: {
          name: {
            type: "string",
            description: "A unique name for the SSH key"
          },
          private_key: {
            type: "string",
            description: "The private key in PEM or OpenSSH format"
          },
          passphrase: {
            type: "string",
            description: "Optional passphrase for the key (stored encrypted)"
          },
          comment: {
            type: "string",
            description: "Optional comment/description for the key"
          },
          metadata: {
            type: "object",
            description: "Optional metadata to attach to the key"
          }
        },
        required: [ "name", "private_key" ]
      }.freeze

      def call(params)
        name = params[:name]
        private_key = params[:private_key]

        return error("name is required") unless name.present?
        return error("private_key is required") unless private_key.present?

        # Check if key with this name already exists
        existing = project.ssh_client_keys.active.find_by(name: name)
        return error("SSH client key already exists with name: #{name}") if existing

        # Import and validate the key
        imported = Ssh::KeyImporter.import(private_key, passphrase: params[:passphrase])

        # Create the key record
        key = SshClientKey.create_encrypted(
          project: project,
          name: name,
          key_type: imported.key_type,
          public_key: imported.public_key,
          private_key: imported.private_key,
          fingerprint: imported.fingerprint,
          key_bits: imported.key_bits,
          passphrase: params[:passphrase],
          comment: params[:comment],
          metadata: params[:metadata] || {}
        )

        log_access(
          action: "mcp_set_ssh_client_key",
          details: {
            name: name,
            key_type: imported.key_type,
            fingerprint: imported.fingerprint
          }
        )

        success(
          name: key.name,
          key_type: key.key_type,
          fingerprint: key.fingerprint,
          key_bits: key.key_bits,
          public_key: key.public_key,
          has_passphrase: key.has_passphrase?,
          created: true
        )
      rescue Ssh::KeyImporter::ImportError => e
        error("Failed to import key: #{e.message}")
      rescue ActiveRecord::RecordInvalid => e
        error("Failed to save key: #{e.message}")
      end
    end
  end
end
