module Encryption
  class Encryptor
    ALGORITHM = "aes-256-gcm"
    AUTH_TAG_LENGTH = 16

    EncryptedData = Struct.new(:ciphertext, :iv, :key_id, keyword_init: true)

    class << self
      def encrypt(plaintext, project_id: nil)
        key = KeyManager.current_key(project_id)

        cipher = OpenSSL::Cipher.new(ALGORITHM)
        cipher.encrypt
        cipher.key = key.raw_key

        iv = cipher.random_iv
        cipher.iv = iv
        cipher.auth_data = ""

        encrypted = cipher.update(plaintext) + cipher.final
        auth_tag = cipher.auth_tag

        EncryptedData.new(
          ciphertext: encrypted + auth_tag,
          iv: iv,
          key_id: key.key_id
        )
      end

      def decrypt(ciphertext, iv:, key_id:, project_id: nil)
        key = KeyManager.get_key(key_id, project_id: project_id)

        cipher = OpenSSL::Cipher.new(ALGORITHM)
        cipher.decrypt
        cipher.key = key.raw_key
        cipher.iv = iv
        cipher.auth_data = ""

        # Extract auth tag (last 16 bytes)
        auth_tag = ciphertext[-AUTH_TAG_LENGTH..]
        encrypted = ciphertext[0...-AUTH_TAG_LENGTH]

        cipher.auth_tag = auth_tag
        cipher.update(encrypted) + cipher.final
      rescue OpenSSL::Cipher::CipherError => e
        raise DecryptionError, "Failed to decrypt: #{e.message}"
      end

      def generate_iv
        OpenSSL::Cipher.new(ALGORITHM).random_iv
      end
    end

    class DecryptionError < StandardError; end
  end
end
