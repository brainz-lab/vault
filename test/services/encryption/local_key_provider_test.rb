# frozen_string_literal: true

require "test_helper"

module Encryption
  class LocalKeyProviderTest < ActiveSupport::TestCase
    setup do
      # Set up master key for testing
      Rails.application.config.vault_master_key = "test-master-key-for-testing"
      @provider = LocalKeyProvider.new
    end

    test "provider_name returns local" do
      assert_equal "local", @provider.provider_name
    end

    test "encrypt returns hash with ciphertext and iv" do
      result = @provider.encrypt("secret data")

      assert result.is_a?(Hash)
      assert result[:ciphertext].present?
      assert result[:iv].present?
      assert_equal 12, result[:iv].bytesize  # AES-GCM uses 12-byte IV
    end

    test "decrypt reverses encrypt" do
      plaintext = "secret data to encrypt"
      encrypted = @provider.encrypt(plaintext)

      decrypted = @provider.decrypt(encrypted[:ciphertext], iv: encrypted[:iv])

      assert_equal plaintext, decrypted
    end

    test "encrypt produces different ciphertext each time" do
      plaintext = "same data"
      result1 = @provider.encrypt(plaintext)
      result2 = @provider.encrypt(plaintext)

      assert_not_equal result1[:ciphertext], result2[:ciphertext]
      assert_not_equal result1[:iv], result2[:iv]
    end

    test "decrypt with wrong iv raises error" do
      encrypted = @provider.encrypt("test data")
      wrong_iv = OpenSSL::Random.random_bytes(12)

      assert_raises(OpenSSL::Cipher::CipherError) do
        @provider.decrypt(encrypted[:ciphertext], iv: wrong_iv)
      end
    end

    test "decrypt with tampered ciphertext raises error" do
      encrypted = @provider.encrypt("test data")
      tampered = encrypted[:ciphertext].bytes
      tampered[0] = (tampered[0] + 1) % 256
      tampered_ciphertext = tampered.pack("C*")

      assert_raises(OpenSSL::Cipher::CipherError) do
        @provider.decrypt(tampered_ciphertext, iv: encrypted[:iv])
      end
    end

    test "raises error when master key is not set" do
      Rails.application.config.vault_master_key = nil

      assert_raises(RuntimeError, "VAULT_MASTER_KEY environment variable must be set") do
        LocalKeyProvider.new
      end
    ensure
      Rails.application.config.vault_master_key = "test-master-key-for-testing"
    end

    test "handles empty string encryption" do
      encrypted = @provider.encrypt("")
      decrypted = @provider.decrypt(encrypted[:ciphertext], iv: encrypted[:iv])
      assert_equal "", decrypted
    end

    test "handles binary data encryption" do
      binary_data = "\x00\x01\x02\xFF\xFE\xFD".b
      encrypted = @provider.encrypt(binary_data)
      decrypted = @provider.decrypt(encrypted[:ciphertext], iv: encrypted[:iv])
      assert_equal binary_data.bytes, decrypted.bytes
    end
  end
end
