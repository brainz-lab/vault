require "rails_helper"

RSpec.describe SecretVersion, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:secret).counter_cache(:versions_count) }
    it { is_expected.to belong_to(:secret_environment) }
  end

  describe "validations" do
    subject { build(:secret_version) }

    it { is_expected.to validate_presence_of(:version) }
    it { is_expected.to validate_presence_of(:encrypted_value) }
    it { is_expected.to validate_presence_of(:encryption_iv) }

    describe "version numericality" do
      it "accepts version greater than 0" do
        sv = create(:secret_version, version: 1)
        expect(sv).to be_valid
      end

      it "rejects version of 0" do
        sv = build(:secret_version, version: 0)
        sv.valid?
        expect(sv.errors[:version]).to be_present
      end

      it "rejects negative version" do
        sv = build(:secret_version, version: -1)
        sv.valid?
        expect(sv.errors[:version]).to be_present
      end
    end
  end

  describe "callbacks" do
    describe "after_create :audit_creation" do
      it "creates an audit log entry after creation" do
        secret = create(:secret, project: create(:project))
        environment = secret.project.secret_environments.first

        expect {
          create(:secret_version, secret: secret, secret_environment: environment)
        }.to change(AuditLog, :count).by(1)
      end
    end
  end

  describe "#decrypt" do
    it "delegates to Encryption::Encryptor.decrypt" do
      sv = create(:secret_version)
      expect(sv.decrypt).to be_a(String)
    end

    it "returns the original plaintext value" do
      sv = create(:secret_version)
      expect(sv.decrypt).not_to be_empty
    end
  end

  describe "#expired?" do
    it "returns false when expires_at is nil" do
      sv = build(:secret_version, expires_at: nil)
      expect(sv.expired?).to be false
    end

    it "returns true when expires_at is in the past" do
      sv = build(:secret_version, expires_at: 1.hour.ago)
      expect(sv.expired?).to be true
    end

    it "returns false when expires_at is in the future" do
      sv = build(:secret_version, expires_at: 1.hour.from_now)
      expect(sv.expired?).to be false
    end
  end

  describe "#has_otp_secret?" do
    it "returns true when both encrypted_otp_secret and otp_secret_iv are present" do
      sv = build(:secret_version, encrypted_otp_secret: "enc", otp_secret_iv: "iv")
      expect(sv.has_otp_secret?).to be true
    end

    it "returns false when encrypted_otp_secret is missing" do
      sv = build(:secret_version, encrypted_otp_secret: nil, otp_secret_iv: "iv")
      expect(sv.has_otp_secret?).to be false
    end

    it "returns false when otp_secret_iv is missing" do
      sv = build(:secret_version, encrypted_otp_secret: "enc", otp_secret_iv: nil)
      expect(sv.has_otp_secret?).to be false
    end
  end

  describe "#value_preview" do
    context "when decryption returns a long value" do
      it "returns first 4 chars + '...' + last 4 chars" do
        sv = create(:secret_version)
        allow(sv).to receive(:decrypt).and_return("abcdefghijklmn")
        preview = sv.value_preview
        expect(preview).to eq("abcd...klmn")
      end
    end

    context "when decryption returns a short value (8 chars or fewer)" do
      it "returns obfuscated placeholder" do
        sv = create(:secret_version)
        allow(sv).to receive(:decrypt).and_return("short")
        expect(sv.value_preview).to eq("••••••••")
      end
    end

    context "when decryption raises an error" do
      it "returns obfuscated placeholder" do
        sv = create(:secret_version)
        allow(sv).to receive(:decrypt).and_raise(StandardError)
        expect(sv.value_preview).to eq("••••••••")
      end
    end
  end
end
