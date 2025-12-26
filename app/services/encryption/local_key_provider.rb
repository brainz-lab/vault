module Encryption
  class LocalKeyProvider
    ALGORITHM = "aes-256-gcm"
    AUTH_TAG_LENGTH = 16

    def initialize
      @master_key = derive_master_key
    end

    def provider_name
      "local"
    end

    def encrypt(plaintext)
      cipher = OpenSSL::Cipher.new(ALGORITHM)
      cipher.encrypt
      cipher.key = @master_key

      iv = cipher.random_iv
      cipher.iv = iv
      cipher.auth_data = ""

      encrypted = cipher.update(plaintext) + cipher.final
      auth_tag = cipher.auth_tag

      {
        ciphertext: encrypted + auth_tag,
        iv: iv
      }
    end

    def decrypt(ciphertext, iv:)
      cipher = OpenSSL::Cipher.new(ALGORITHM)
      cipher.decrypt
      cipher.key = @master_key
      cipher.iv = iv
      cipher.auth_data = ""

      auth_tag = ciphertext[-AUTH_TAG_LENGTH..]
      encrypted = ciphertext[0...-AUTH_TAG_LENGTH]

      cipher.auth_tag = auth_tag
      cipher.update(encrypted) + cipher.final
    end

    private

    def derive_master_key
      master_key_base = Rails.application.config.vault_master_key

      unless master_key_base.present?
        raise "VAULT_MASTER_KEY environment variable must be set"
      end

      # Use PBKDF2 to derive a key from the master key
      OpenSSL::PKCS5.pbkdf2_hmac(
        master_key_base,
        "vault-key-derivation-salt",
        100_000,
        32,
        OpenSSL::Digest::SHA256.new
      )
    end
  end
end
