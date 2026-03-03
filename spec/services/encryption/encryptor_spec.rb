require "rails_helper"

RSpec.describe Encryption::Encryptor do
  before do
    setup_master_key
    EncryptionKey.delete_all
    @default_project = create(:project, name: "Encryptor Test Project")
  end

  describe "constants" do
    it "ALGORITHM is aes-256-gcm" do
      expect(described_class::ALGORITHM).to eq("aes-256-gcm")
    end

    it "AUTH_TAG_LENGTH is 16" do
      expect(described_class::AUTH_TAG_LENGTH).to eq(16)
    end
  end

  describe ".encrypt" do
    it "returns EncryptedData struct" do
      result = described_class.encrypt("test data", project_id: @default_project.id)
      expect(result).to be_a(described_class::EncryptedData)
      expect(result.ciphertext).to be_present
      expect(result.iv).to be_present
      expect(result.key_id).to be_present
    end
  end

  describe "encrypt and decrypt roundtrip" do
    it "decrypts to original plaintext" do
      plaintext = "secret data to encrypt"
      encrypted = described_class.encrypt(plaintext, project_id: @default_project.id)
      decrypted = described_class.decrypt(encrypted.ciphertext, iv: encrypted.iv, key_id: encrypted.key_id, project_id: @default_project.id)
      expect(decrypted).to eq(plaintext)
    end

    it "uses project-specific key" do
      project = create(:project)
      encrypted = described_class.encrypt("data", project_id: project.id)
      expect(encrypted.key_id).to be_present
      decrypted = described_class.decrypt(encrypted.ciphertext, iv: encrypted.iv, key_id: encrypted.key_id, project_id: project.id)
      expect(decrypted).to eq("data")
    end
  end

  describe ".decrypt" do
    it "raises RecordNotFound with invalid key_id" do
      encrypted = described_class.encrypt("test", project_id: @default_project.id)
      expect {
        described_class.decrypt(encrypted.ciphertext, iv: encrypted.iv, key_id: "non-existent-key-id", project_id: @default_project.id)
      }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "raises DecryptionError with wrong iv" do
      encrypted = described_class.encrypt("test", project_id: @default_project.id)
      wrong_iv = OpenSSL::Random.random_bytes(12)
      expect {
        described_class.decrypt(encrypted.ciphertext, iv: wrong_iv, key_id: encrypted.key_id, project_id: @default_project.id)
      }.to raise_error(described_class::DecryptionError)
    end
  end

  describe ".generate_iv" do
    it "returns 12-byte iv" do
      expect(described_class.generate_iv.bytesize).to eq(12)
    end

    it "produces unique values" do
      expect(described_class.generate_iv).not_to eq(described_class.generate_iv)
    end
  end

  it "handles unicode text" do
    plaintext = "Hello 世界 🔐 Ключ"
    encrypted = described_class.encrypt(plaintext, project_id: @default_project.id)
    decrypted = described_class.decrypt(encrypted.ciphertext, iv: encrypted.iv, key_id: encrypted.key_id, project_id: @default_project.id)
    expect(decrypted.force_encoding("UTF-8")).to eq(plaintext)
  end

  it "handles large data" do
    plaintext = "A" * 100_000
    encrypted = described_class.encrypt(plaintext, project_id: @default_project.id)
    decrypted = described_class.decrypt(encrypted.ciphertext, iv: encrypted.iv, key_id: encrypted.key_id, project_id: @default_project.id)
    expect(decrypted).to eq(plaintext)
  end
end
