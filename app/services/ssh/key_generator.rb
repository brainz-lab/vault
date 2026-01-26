require "net/ssh"
require "openssl"

module Ssh
  class KeyGenerator
    SUPPORTED_TYPES = {
      "rsa-2048" => { algorithm: :rsa, bits: 2048 },
      "rsa-4096" => { algorithm: :rsa, bits: 4096 },
      "ed25519" => { algorithm: :ed25519, bits: 256 }
    }.freeze

    GeneratedKey = Struct.new(:private_key, :public_key, :fingerprint, :key_type, :key_bits, keyword_init: true)

    class << self
      # Generate a new SSH key pair
      def generate(key_type:, comment: nil)
        config = SUPPORTED_TYPES[key_type]
        raise ArgumentError, "Unsupported key type: #{key_type}. Supported: #{SUPPORTED_TYPES.keys.join(", ")}" unless config

        case config[:algorithm]
        when :rsa
          generate_rsa(bits: config[:bits], comment: comment, key_type: key_type)
        when :ed25519
          generate_ed25519(comment: comment, key_type: key_type)
        end
      end

      # Calculate fingerprint from public key
      def fingerprint(public_key)
        # Parse the public key to get the raw key data
        parts = public_key.strip.split(" ")
        key_type = parts[0]
        key_data = parts[1]

        # Decode and hash
        decoded = Base64.decode64(key_data)
        hash = OpenSSL::Digest::SHA256.digest(decoded)
        "SHA256:#{Base64.strict_encode64(hash).chomp("=")}"
      end

      # Validate that a key type is supported
      def valid_type?(key_type)
        SUPPORTED_TYPES.key?(key_type)
      end

      # Get supported key types
      def supported_types
        SUPPORTED_TYPES.keys
      end

      private

      def generate_rsa(bits:, comment:, key_type:)
        # Generate RSA key using OpenSSL
        rsa_key = OpenSSL::PKey::RSA.new(bits)

        # Format private key as PEM
        private_key_pem = rsa_key.to_pem

        # Format public key as OpenSSH format
        public_key_ssh = ssh_public_key_from_rsa(rsa_key, comment)

        # Calculate fingerprint
        fp = fingerprint(public_key_ssh)

        GeneratedKey.new(
          private_key: private_key_pem,
          public_key: public_key_ssh,
          fingerprint: fp,
          key_type: key_type,
          key_bits: bits
        )
      end

      def generate_ed25519(comment:, key_type:)
        # Generate Ed25519 key
        # Note: This requires the ed25519 gem
        require "ed25519"

        signing_key = Ed25519::SigningKey.generate
        verify_key = signing_key.verify_key

        # Format private key as OpenSSH format
        private_key_openssh = format_ed25519_private_key(signing_key, verify_key, comment)

        # Format public key as OpenSSH format
        public_key_ssh = format_ed25519_public_key(verify_key, comment)

        # Calculate fingerprint
        fp = fingerprint(public_key_ssh)

        GeneratedKey.new(
          private_key: private_key_openssh,
          public_key: public_key_ssh,
          fingerprint: fp,
          key_type: key_type,
          key_bits: 256
        )
      end

      def ssh_public_key_from_rsa(rsa_key, comment)
        # Build SSH public key format
        # Format: ssh-rsa <base64-encoded-data> <comment>
        e = rsa_key.e.to_s(2)
        n = rsa_key.n.to_s(2)

        # Ensure positive integers (prepend 0x00 if high bit is set)
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

        encoded = Base64.strict_encode64(blob)
        comment_str = comment.present? ? " #{comment}" : ""
        "ssh-rsa #{encoded}#{comment_str}"
      end

      def format_ed25519_public_key(verify_key, comment)
        key_type = "ssh-ed25519"
        blob = [
          [key_type.length].pack("N"),
          key_type,
          [32].pack("N"),
          verify_key.to_bytes
        ].join

        encoded = Base64.strict_encode64(blob)
        comment_str = comment.present? ? " #{comment}" : ""
        "ssh-ed25519 #{encoded}#{comment_str}"
      end

      def format_ed25519_private_key(signing_key, verify_key, comment)
        # OpenSSH private key format
        auth_magic = "openssh-key-v1\x00"
        cipher_name = "none"
        kdf_name = "none"
        kdf_options = ""
        num_keys = 1

        # Public key blob
        pub_key_type = "ssh-ed25519"
        pub_blob = [
          [pub_key_type.length].pack("N"),
          pub_key_type,
          [32].pack("N"),
          verify_key.to_bytes
        ].join

        # Private key section (unencrypted)
        check_int = SecureRandom.random_bytes(4)
        priv_comment = comment || ""

        # Private key data: 32-byte seed + 32-byte public key
        private_data = signing_key.to_bytes + verify_key.to_bytes

        priv_section = [
          check_int,
          check_int,
          [pub_key_type.length].pack("N"),
          pub_key_type,
          [32].pack("N"),
          verify_key.to_bytes,
          [64].pack("N"),
          private_data,
          [priv_comment.length].pack("N"),
          priv_comment
        ].join

        # Pad to block size (8 bytes for none cipher)
        padding_length = (8 - (priv_section.length % 8)) % 8
        priv_section += (1..padding_length).map(&:chr).join

        # Build full key
        full_key = [
          auth_magic,
          [cipher_name.length].pack("N"),
          cipher_name,
          [kdf_name.length].pack("N"),
          kdf_name,
          [kdf_options.length].pack("N"),
          kdf_options,
          [num_keys].pack("N"),
          [pub_blob.length].pack("N"),
          pub_blob,
          [priv_section.length].pack("N"),
          priv_section
        ].join

        # Wrap in PEM format
        encoded = Base64.strict_encode64(full_key).scan(/.{1,70}/).join("\n")
        "-----BEGIN OPENSSH PRIVATE KEY-----\n#{encoded}\n-----END OPENSSH PRIVATE KEY-----\n"
      end
    end
  end
end
