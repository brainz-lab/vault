module Mcp
  module Tools
    class SshGenerateKey < Base
      DESCRIPTION = "Generate a new SSH key pair and store it in the vault."
      INPUT_SCHEMA = {
        type: "object",
        properties: {
          name: {
            type: "string",
            description: "A unique name for the SSH key"
          },
          key_type: {
            type: "string",
            enum: [ "rsa-2048", "rsa-4096", "ed25519" ],
            description: "Type of key to generate (default: ed25519)"
          },
          passphrase: {
            type: "string",
            description: "Optional passphrase to protect the key (stored encrypted)"
          },
          comment: {
            type: "string",
            description: "Optional comment to embed in the public key"
          },
          metadata: {
            type: "object",
            description: "Optional metadata to attach to the key"
          }
        },
        required: [ "name" ]
      }.freeze

      def call(params)
        name = params[:name]
        key_type = params[:key_type] || "ed25519"

        return error("name is required") unless name.present?

        # Check if key with this name already exists
        existing = project.ssh_client_keys.active.find_by(name: name)
        return error("SSH client key already exists with name: #{name}") if existing

        # Validate key type
        unless Ssh::KeyGenerator.valid_type?(key_type)
          return error("Invalid key type: #{key_type}. Supported: #{Ssh::KeyGenerator.supported_types.join(", ")}")
        end

        # Generate the key
        generated = Ssh::KeyGenerator.generate(
          key_type: key_type,
          comment: params[:comment] || "#{name}@vault"
        )

        # Store the key
        key = SshClientKey.create_encrypted(
          project: project,
          name: name,
          key_type: generated.key_type,
          public_key: generated.public_key,
          private_key: generated.private_key,
          fingerprint: generated.fingerprint,
          key_bits: generated.key_bits,
          passphrase: params[:passphrase],
          comment: params[:comment],
          metadata: params[:metadata] || {}
        )

        log_access(
          action: "mcp_generate_ssh_key",
          details: {
            name: name,
            key_type: key_type,
            fingerprint: generated.fingerprint
          }
        )

        success(
          name: key.name,
          key_type: key.key_type,
          fingerprint: key.fingerprint,
          key_bits: key.key_bits,
          public_key: key.public_key,
          private_key: key.decrypt_private_key,
          has_passphrase: key.has_passphrase?,
          created: true
        )
      rescue ActiveRecord::RecordInvalid => e
        error("Failed to save key: #{e.message}")
      end
    end
  end
end
