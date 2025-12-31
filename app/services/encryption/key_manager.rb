module Encryption
  class KeyManager
    KeyWrapper = Struct.new(:record, :raw_key) do
      def key_id
        record.key_id
      end
    end

    class << self
      def current_key(project_id = nil)
        # Get the active key for the project
        key_record = EncryptionKey.where(status: "active")
        key_record = key_record.where(project_id: project_id) if project_id
        key_record = key_record.order(created_at: :desc).first

        key_record ? decrypt_key(key_record) : create_key(project_id)
      end

      def get_key(key_id, project_id: nil)
        key_record = if project_id
                       EncryptionKey.find_by!(key_id: key_id, project_id: project_id)
        else
                       EncryptionKey.find_by!(key_id: key_id)
        end
        decrypt_key(key_record)
      end

      def create_key(project_id)
        raw_key = OpenSSL::Random.random_bytes(32)  # 256 bits

        # Encrypt with master key
        encrypted = master_key_provider.encrypt(raw_key)

        key_record = EncryptionKey.create!(
          project_id: project_id,
          key_id: SecureRandom.uuid,
          key_type: "aes-256-gcm",
          encrypted_key: encrypted[:ciphertext],
          encryption_iv: encrypted[:iv],
          kms_provider: master_key_provider.provider_name,
          status: "active",
          activated_at: Time.current
        )

        KeyWrapper.new(key_record, raw_key)
      end

      def rotate_key(project_id)
        old_key = current_key(project_id)
        new_key = create_key(project_id)

        # Mark old key as rotating
        old_key.record.update!(status: "rotating")

        # Re-encrypt all secrets with new key
        SecretVersion.joins(:secret)
                     .where(secrets: { project_id: project_id })
                     .where(encryption_key_id: old_key.key_id)
                     .find_each do |version|
          # Decrypt with old key, encrypt with new key
          plaintext = Encryptor.decrypt(
            version.encrypted_value,
            iv: version.encryption_iv,
            key_id: old_key.key_id,
            project_id: project_id
          )

          encrypted = Encryptor.encrypt(plaintext, project_id: project_id)

          version.update!(
            encrypted_value: encrypted.ciphertext,
            encryption_iv: encrypted.iv,
            encryption_key_id: encrypted.key_id
          )
        end

        # Retire old key
        old_key.record.update!(status: "retired", retired_at: Time.current)

        new_key
      end

      private

      def master_key_provider
        @master_key_provider ||= LocalKeyProvider.new
      end

      def decrypt_key(key_record)
        raw_key = master_key_provider.decrypt(
          key_record.encrypted_key,
          iv: key_record.encryption_iv
        )

        KeyWrapper.new(key_record, raw_key)
      end
    end
  end
end
