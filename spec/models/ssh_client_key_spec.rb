require "rails_helper"

RSpec.describe SshClientKey, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:project) }
    it { is_expected.to have_many(:ssh_connections).dependent(:nullify) }
  end

  describe "validations" do
    subject { build(:ssh_client_key) }

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:key_type) }
    it { is_expected.to validate_presence_of(:fingerprint) }
    it { is_expected.to validate_presence_of(:public_key) }
    it { is_expected.to validate_presence_of(:encrypted_private_key) }
    it { is_expected.to validate_presence_of(:private_key_iv) }
    it { is_expected.to validate_presence_of(:private_key_key_id) }
    it { is_expected.to validate_inclusion_of(:key_type).in_array(%w[rsa-2048 rsa-4096 ed25519]) }

    it "rejects an unsupported key_type" do
      key = build(:ssh_client_key, key_type: "dsa-1024")
      key.valid?
      expect(key.errors[:key_type]).to be_present
    end
  end

  describe "scopes" do
    let(:project) { create(:project) }

    describe ".active" do
      let!(:active_key)   { create(:ssh_client_key, project: project, archived: false) }
      let!(:archived_key) { create(:ssh_client_key, project: project, archived: true) }

      it "returns only non-archived keys" do
        expect(SshClientKey.active).to include(active_key)
        expect(SshClientKey.active).not_to include(archived_key)
      end
    end

    describe ".by_type" do
      let!(:rsa_key)  { create(:ssh_client_key, project: project, key_type: "rsa-4096") }
      let!(:ed_key)   { create(:ssh_client_key, project: project, key_type: "ed25519") }

      it "returns keys of the specified type" do
        expect(SshClientKey.by_type("rsa-4096")).to include(rsa_key)
        expect(SshClientKey.by_type("rsa-4096")).not_to include(ed_key)
      end
    end

    describe ".by_fingerprint" do
      let!(:key_a) { create(:ssh_client_key, project: project, fingerprint: "SHA256:aaa") }
      let!(:key_b) { create(:ssh_client_key, project: project, fingerprint: "SHA256:bbb") }

      it "returns keys with the matching fingerprint" do
        expect(SshClientKey.by_fingerprint("SHA256:aaa")).to include(key_a)
        expect(SshClientKey.by_fingerprint("SHA256:aaa")).not_to include(key_b)
      end
    end
  end

  describe ".create_encrypted" do
    let(:project) { create(:project) }

    it "creates a new SshClientKey with encrypted private key" do
      expect {
        SshClientKey.create_encrypted(
          project: project,
          name: "deploy-key",
          key_type: "ed25519",
          public_key: "ssh-ed25519 AAAA...",
          private_key: "-----BEGIN OPENSSH PRIVATE KEY-----\ntest\n-----END OPENSSH PRIVATE KEY-----",
          fingerprint: "SHA256:test123"
        )
      }.to change(SshClientKey, :count).by(1)
    end

    it "stores encrypted_private_key (not plaintext)" do
      key = SshClientKey.create_encrypted(
        project: project,
        name: "deploy-key",
        key_type: "ed25519",
        public_key: "ssh-ed25519 AAAA...",
        private_key: "plaintext_private_key",
        fingerprint: "SHA256:test123"
      )
      expect(key.encrypted_private_key).not_to eq("plaintext_private_key")
    end
  end

  describe "#decrypt_private_key" do
    let(:key) { create(:ssh_client_key) }

    it "returns a non-empty string" do
      expect(key.decrypt_private_key).to be_a(String)
      expect(key.decrypt_private_key).not_to be_empty
    end
  end

  describe "#has_passphrase?" do
    it "returns true when encrypted_passphrase is present" do
      key = build(:ssh_client_key, encrypted_passphrase: "encrypted_value")
      expect(key.has_passphrase?).to be true
    end

    it "returns false when encrypted_passphrase is nil" do
      key = build(:ssh_client_key, encrypted_passphrase: nil)
      expect(key.has_passphrase?).to be false
    end
  end

  describe "#archive!" do
    let(:key) { create(:ssh_client_key, archived: false) }

    it "sets archived to true" do
      key.archive!
      expect(key.reload.archived).to be true
    end
  end

  describe "#restore!" do
    let(:key) { create(:ssh_client_key, archived: true) }

    it "sets archived to false" do
      key.restore!
      expect(key.reload.archived).to be false
    end
  end

  describe "#to_summary" do
    let(:key) { create(:ssh_client_key) }

    it "returns a hash" do
      expect(key.to_summary).to be_a(Hash)
    end

    it "includes public key information" do
      summary = key.to_summary
      expect(summary).to have_key(:name).or have_key("name")
    end

    it "does not include the private key" do
      summary = key.to_summary
      summary_str = summary.to_s
      expect(summary_str).not_to include("encrypted_private_key")
    end
  end
end
