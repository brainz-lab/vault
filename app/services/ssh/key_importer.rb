require "openssl"

module Ssh
  class KeyImporter
    ImportedKey = Struct.new(:private_key, :public_key, :fingerprint, :key_type, :key_bits, keyword_init: true)

    class ImportError < StandardError; end

    class << self
      # Import and validate a private key
      def import(private_key_pem, passphrase: nil)
        # Detect key type and parse
        if private_key_pem.include?("OPENSSH PRIVATE KEY")
          import_openssh_key(private_key_pem, passphrase)
        elsif private_key_pem.include?("RSA PRIVATE KEY") || private_key_pem.include?("PRIVATE KEY")
          import_pem_key(private_key_pem, passphrase)
        else
          raise ImportError, "Unrecognized private key format"
        end
      rescue OpenSSL::PKey::PKeyError => e
        raise ImportError, "Failed to parse private key: #{e.message}"
      end

      # Validate a private key without importing
      def valid?(private_key_pem, passphrase: nil)
        import(private_key_pem, passphrase: passphrase)
        true
      rescue ImportError
        false
      end

      private

      def import_pem_key(pem, passphrase)
        # Try to parse as RSA key
        key = if passphrase.present?
          OpenSSL::PKey::RSA.new(pem, passphrase)
        else
          OpenSSL::PKey::RSA.new(pem)
        end

        # Determine key size and type
        bits = key.n.num_bits
        key_type = bits <= 2048 ? "rsa-2048" : "rsa-4096"

        # Generate public key in SSH format
        public_key = ssh_public_key_from_rsa(key)

        # Calculate fingerprint
        fp = Ssh::KeyGenerator.fingerprint(public_key)

        ImportedKey.new(
          private_key: key.to_pem,
          public_key: public_key,
          fingerprint: fp,
          key_type: key_type,
          key_bits: bits
        )
      end

      def import_openssh_key(openssh_key, passphrase)
        # Parse OpenSSH format private key
        # This is a simplified parser - for production, use net-ssh gem

        # Check if encrypted
        if passphrase.present?
          # For encrypted keys, we need to use net-ssh or similar
          # For now, we'll try OpenSSL first
          begin
            return import_pem_key(openssh_key, passphrase)
          rescue OpenSSL::PKey::PKeyError
            # Fall through to manual parsing
          end
        end

        # Decode the key to detect type from binary content
        lines = openssh_key.strip.split("\n")
        lines = lines.reject { |l| l.start_with?("-----") }
        encoded = lines.join
        decoded = Base64.decode64(encoded)

        # Check for Ed25519 key type in decoded binary data
        # The key type "ssh-ed25519" appears as a length-prefixed string in the binary
        if decoded.include?("ssh-ed25519")
          import_ed25519_openssh(openssh_key)
        else
          # Try as RSA in OpenSSH format
          import_rsa_openssh(openssh_key)
        end
      end

      def import_ed25519_openssh(openssh_key)
        # Parse the OpenSSH format
        # Remove header/footer and decode
        lines = openssh_key.strip.split("\n")
        lines = lines.reject { |l| l.start_with?("-----") }
        encoded = lines.join

        data = Base64.decode64(encoded)

        # Verify magic
        auth_magic = "openssh-key-v1\x00"
        unless data.start_with?(auth_magic)
          raise ImportError, "Invalid OpenSSH private key format"
        end

        # For Ed25519 keys, extract the public key part for fingerprint
        # The full parsing is complex, so we'll extract what we need

        # Find the public key section
        if data.include?("ssh-ed25519")
          # Extract the 32-byte public key
          idx = data.index("ssh-ed25519")
          # Skip past key type string
          idx += 11 # length of "ssh-ed25519"

          # Read the length prefix for public key data
          if idx + 4 <= data.length
            # The public key data follows
            # Build the public key SSH format
            pub_key_start = data.index("ssh-ed25519")

            # Build SSH public key format manually
            # Find the raw public key bytes (32 bytes after the type string in pub section)
            pub_section_start = data.index("\x00\x00\x00\x0bssh-ed25519")
            if pub_section_start
              pub_start = pub_section_start + 15 + 4 # type + length prefix
              pub_bytes = data[pub_start, 32]

              key_type_str = "ssh-ed25519"
              blob = [
                [key_type_str.length].pack("N"),
                key_type_str,
                [32].pack("N"),
                pub_bytes
              ].join

              public_key = "ssh-ed25519 #{Base64.strict_encode64(blob)}"
              fp = Ssh::KeyGenerator.fingerprint(public_key)

              return ImportedKey.new(
                private_key: openssh_key,
                public_key: public_key,
                fingerprint: fp,
                key_type: "ed25519",
                key_bits: 256
              )
            end
          end
        end

        raise ImportError, "Failed to parse Ed25519 OpenSSH key"
      end

      def import_rsa_openssh(openssh_key)
        # Try to use OpenSSL to parse (works for some RSA keys in OpenSSH format)
        begin
          key = OpenSSL::PKey::RSA.new(openssh_key)
          return import_pem_key(key.to_pem, nil)
        rescue OpenSSL::PKey::PKeyError
          raise ImportError, "Failed to parse RSA OpenSSH key. Please convert to PEM format."
        end
      end

      def ssh_public_key_from_rsa(rsa_key)
        e = rsa_key.e.to_s(2)
        n = rsa_key.n.to_s(2)

        e = "\x00" + e if e.bytes.first >= 128
        n = "\x00" + n if n.bytes.first >= 128

        key_type = "ssh-rsa"
        blob = [
          [key_type.length].pack("N"),
          key_type,
          [e.length].pack("N"),
          e,
          [n.length].pack("N"),
          n
        ].join

        "ssh-rsa #{Base64.strict_encode64(blob)}"
      end
    end
  end
end
