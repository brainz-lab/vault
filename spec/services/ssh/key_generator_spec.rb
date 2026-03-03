require "rails_helper"

RSpec.describe Ssh::KeyGenerator do
  describe ".generate" do
    context "with ed25519 key type" do
      it "generates a valid ed25519 key" do
        key = described_class.generate(key_type: "ed25519", comment: "test@vault")

        expect(key).not_to be_nil
        expect(key.key_type).to eq("ed25519")
        expect(key.key_bits).to eq(256)
        expect(key.private_key).not_to be_nil
        expect(key.public_key).not_to be_nil
        expect(key.fingerprint).not_to be_nil

        expect(key.private_key).to include("OPENSSH PRIVATE KEY")
        expect(key.public_key).to start_with("ssh-ed25519")
        expect(key.fingerprint).to start_with("SHA256:")
      end
    end

    context "with rsa-2048 key type" do
      it "generates a valid rsa-2048 key" do
        key = described_class.generate(key_type: "rsa-2048", comment: "test@vault")

        expect(key).not_to be_nil
        expect(key.key_type).to eq("rsa-2048")
        expect(key.key_bits).to eq(2048)
        expect(key.private_key).to include("RSA PRIVATE KEY").or include("PRIVATE KEY")
        expect(key.public_key).to start_with("ssh-rsa")
        expect(key.fingerprint).to start_with("SHA256:")
      end
    end

    context "with rsa-4096 key type" do
      it "generates a valid rsa-4096 key" do
        key = described_class.generate(key_type: "rsa-4096", comment: "test@vault")

        expect(key).not_to be_nil
        expect(key.key_type).to eq("rsa-4096")
        expect(key.key_bits).to eq(4096)
        expect(key.public_key).to start_with("ssh-rsa")
      end
    end

    context "with invalid key type" do
      it "raises ArgumentError" do
        expect {
          described_class.generate(key_type: "invalid")
        }.to raise_error(ArgumentError)
      end
    end

    it "includes comment in public key" do
      key = described_class.generate(key_type: "ed25519", comment: "my-comment")
      expect(key.public_key).to include("my-comment")
    end
  end

  describe ".valid_type?" do
    it "returns true for supported types" do
      expect(described_class.valid_type?("ed25519")).to be true
      expect(described_class.valid_type?("rsa-2048")).to be true
      expect(described_class.valid_type?("rsa-4096")).to be true
    end

    it "returns false for unsupported types" do
      expect(described_class.valid_type?("dsa")).to be false
      expect(described_class.valid_type?("invalid")).to be false
    end
  end

  describe ".supported_types" do
    it "returns all supported types" do
      types = described_class.supported_types
      expect(types).to include("ed25519")
      expect(types).to include("rsa-2048")
      expect(types).to include("rsa-4096")
    end
  end

  describe ".fingerprint" do
    it "calculates SHA256 hash from public key" do
      public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGVqF1n7FqLv1Ktest test@example"
      fp = described_class.fingerprint(public_key)

      expect(fp).to start_with("SHA256:")
      expect(fp.length).to be > 10
    end
  end
end
