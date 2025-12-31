# frozen_string_literal: true

require "test_helper"

module Encryption
  class EncryptorTest < ActiveSupport::TestCase
    setup do
      Rails.application.config.vault_master_key = "test-master-key-for-testing"
      # Delete fixture keys which have invalid encrypted data
      EncryptionKey.delete_all
      # Create a default project for tests that don't specify one
      @default_project = create_project(name: "Encryptor Test Project")
    end

    test "ALGORITHM is aes-256-gcm" do
      assert_equal "aes-256-gcm", Encryptor::ALGORITHM
    end

    test "AUTH_TAG_LENGTH is 16" do
      assert_equal 16, Encryptor::AUTH_TAG_LENGTH
    end

    test "encrypt returns EncryptedData struct" do
      result = Encryptor.encrypt("test data", project_id: @default_project.id)

      assert result.is_a?(Encryptor::EncryptedData)
      assert result.ciphertext.present?
      assert result.iv.present?
      assert result.key_id.present?
    end

    test "encrypt and decrypt roundtrip" do
      plaintext = "secret data to encrypt"
      encrypted = Encryptor.encrypt(plaintext, project_id: @default_project.id)

      decrypted = Encryptor.decrypt(
        encrypted.ciphertext,
        iv: encrypted.iv,
        key_id: encrypted.key_id,
        project_id: @default_project.id
      )

      assert_equal plaintext, decrypted
    end

    test "encrypt uses project-specific key when project_id provided" do
      # Use fresh project to avoid fixture encryption key issues
      project = create_project

      encrypted = Encryptor.encrypt("data", project_id: project.id)

      assert encrypted.key_id.present?

      decrypted = Encryptor.decrypt(
        encrypted.ciphertext,
        iv: encrypted.iv,
        key_id: encrypted.key_id,
        project_id: project.id
      )

      assert_equal "data", decrypted
    end

    test "decrypt with invalid key_id raises error" do
      encrypted = Encryptor.encrypt("test", project_id: @default_project.id)

      assert_raises(ActiveRecord::RecordNotFound) do
        Encryptor.decrypt(
          encrypted.ciphertext,
          iv: encrypted.iv,
          key_id: "non-existent-key-id",
          project_id: @default_project.id
        )
      end
    end

    test "decrypt with wrong iv raises DecryptionError" do
      encrypted = Encryptor.encrypt("test", project_id: @default_project.id)
      wrong_iv = OpenSSL::Random.random_bytes(12)

      assert_raises(Encryptor::DecryptionError) do
        Encryptor.decrypt(
          encrypted.ciphertext,
          iv: wrong_iv,
          key_id: encrypted.key_id,
          project_id: @default_project.id
        )
      end
    end

    test "generate_iv returns 12-byte iv" do
      iv = Encryptor.generate_iv
      assert_equal 12, iv.bytesize
    end

    test "generate_iv produces unique values" do
      iv1 = Encryptor.generate_iv
      iv2 = Encryptor.generate_iv
      assert_not_equal iv1, iv2
    end

    test "handles unicode text encryption" do
      plaintext = "Hello 世界 🔐 Ключ"
      encrypted = Encryptor.encrypt(plaintext, project_id: @default_project.id)

      decrypted = Encryptor.decrypt(
        encrypted.ciphertext,
        iv: encrypted.iv,
        key_id: encrypted.key_id,
        project_id: @default_project.id
      )

      # Force UTF-8 encoding for comparison since decrypt returns binary
      assert_equal plaintext, decrypted.force_encoding("UTF-8")
    end

    test "handles large data encryption" do
      plaintext = "A" * 100_000  # 100KB of data
      encrypted = Encryptor.encrypt(plaintext, project_id: @default_project.id)

      decrypted = Encryptor.decrypt(
        encrypted.ciphertext,
        iv: encrypted.iv,
        key_id: encrypted.key_id,
        project_id: @default_project.id
      )

      assert_equal plaintext, decrypted
    end
  end
end
