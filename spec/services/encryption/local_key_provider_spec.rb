require "rails_helper"

RSpec.describe Encryption::LocalKeyProvider do
  before do
    setup_master_key
    @provider = described_class.new
  end

  describe "#provider_name" do
    it "returns local" do
      expect(@provider.provider_name).to eq("local")
    end
  end

  describe "#encrypt" do
    it "returns hash with ciphertext and iv" do
      result = @provider.encrypt("secret data")

      expect(result).to be_a(Hash)
      expect(result[:ciphertext]).to be_present
      expect(result[:iv]).to be_present
      expect(result[:iv].bytesize).to eq(12)
    end

    it "produces different ciphertext each time" do
      plaintext = "same data"
      result1 = @provider.encrypt(plaintext)
      result2 = @provider.encrypt(plaintext)

      expect(result1[:ciphertext]).not_to eq(result2[:ciphertext])
      expect(result1[:iv]).not_to eq(result2[:iv])
    end
  end

  describe "#decrypt" do
    it "reverses encrypt" do
      plaintext = "secret data to encrypt"
      encrypted = @provider.encrypt(plaintext)

      decrypted = @provider.decrypt(encrypted[:ciphertext], iv: encrypted[:iv])

      expect(decrypted).to eq(plaintext)
    end

    it "raises error with wrong iv" do
      encrypted = @provider.encrypt("test data")
      wrong_iv = OpenSSL::Random.random_bytes(12)

      expect {
        @provider.decrypt(encrypted[:ciphertext], iv: wrong_iv)
      }.to raise_error(OpenSSL::Cipher::CipherError)
    end

    it "raises error with tampered ciphertext" do
      encrypted = @provider.encrypt("test data")
      tampered = encrypted[:ciphertext].bytes
      tampered[0] = (tampered[0] + 1) % 256
      tampered_ciphertext = tampered.pack("C*")

      expect {
        @provider.decrypt(tampered_ciphertext, iv: encrypted[:iv])
      }.to raise_error(OpenSSL::Cipher::CipherError)
    end
  end

  describe "initialization" do
    it "raises error when master key is not set" do
      original_key = Rails.application.config.vault_master_key
      Rails.application.config.vault_master_key = nil

      expect {
        described_class.new
      }.to raise_error(RuntimeError, "VAULT_MASTER_KEY environment variable must be set")
    ensure
      Rails.application.config.vault_master_key = original_key
    end
  end

  describe "edge cases" do
    it "handles empty string encryption" do
      encrypted = @provider.encrypt("")
      decrypted = @provider.decrypt(encrypted[:ciphertext], iv: encrypted[:iv])
      expect(decrypted).to eq("")
    end

    it "handles binary data encryption" do
      binary_data = "\x00\x01\x02\xFF\xFE\xFD".b
      encrypted = @provider.encrypt(binary_data)
      decrypted = @provider.decrypt(encrypted[:ciphertext], iv: encrypted[:iv])
      expect(decrypted.bytes).to eq(binary_data.bytes)
    end
  end
end
