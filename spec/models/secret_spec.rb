require "rails_helper"

RSpec.describe Secret, type: :model do
  describe "constants" do
    it "defines SECRET_TYPES" do
      expect(Secret::SECRET_TYPES).to eq(%w[string json file certificate credential totp hotp])
    end

    it "defines OTP_TYPES" do
      expect(Secret::OTP_TYPES).to eq(%w[credential totp hotp])
    end
  end

  describe "associations" do
    it { is_expected.to belong_to(:project) }
    it { is_expected.to belong_to(:secret_folder).optional }
    it { is_expected.to have_many(:versions).class_name("SecretVersion") }
  end

  describe "validations" do
    subject { build(:secret) }

    it "auto-generates path from key via set_path callback" do
      secret = create(:secret, key: "MY_KEY")
      expect(secret.path).to be_present
    end

    it "enforces uniqueness of path scoped to project" do
      existing = create(:secret)
      duplicate = build(:secret, project: existing.project, key: existing.key)
      duplicate.path = existing.path
      duplicate.valid?
      expect(duplicate.errors[:path]).to be_present
    end
    it { is_expected.to validate_inclusion_of(:secret_type).in_array(Secret::SECRET_TYPES) }

    describe "key format" do
      it "accepts valid uppercase keys" do
        secret = build(:secret, key: "DATABASE_URL")
        expect(secret).to be_valid
      end

      it "accepts keys starting with a letter followed by digits and underscores" do
        secret = build(:secret, key: "A1_B2_C3")
        expect(secret).to be_valid
      end

      it "normalizes lowercase keys to uppercase via callback" do
        secret = build(:secret, key: "database_url")
        secret.valid?
        expect(secret.key).to eq("DATABASE_URL")
        expect(secret.errors[:key]).to be_empty
      end

      it "normalizes keys starting with a digit by prepending X" do
        secret = build(:secret, key: "1_KEY")
        secret.valid?
        expect(secret.key).to start_with("X")
        expect(secret.errors[:key]).to be_empty
      end
    end

    describe "OTP validations" do
      context "when otp_algorithm is provided" do
        it "validates inclusion in allowed algorithms" do
          secret = build(:secret, secret_type: "totp", otp_algorithm: "INVALID")
          secret.valid?
          expect(secret.errors[:otp_algorithm]).to be_present
        end
      end

      context "when otp_digits is provided" do
        it "accepts values between 6 and 8" do
          (6..8).each do |digits|
            secret = build(:secret, secret_type: "totp", otp_digits: digits)
            expect(secret.errors[:otp_digits]).to be_empty
          end
        end

        it "rejects values outside 6-8" do
          secret = build(:secret, secret_type: "totp", otp_digits: 5)
          secret.valid?
          expect(secret.errors[:otp_digits]).to be_present
        end
      end

      context "when otp_period is provided" do
        it "validates numericality" do
          secret = build(:secret, secret_type: "totp", otp_period: -1)
          secret.valid?
          expect(secret.errors[:otp_period]).to be_present
        end
      end
    end
  end

  describe "callbacks" do
    describe "before_validation :normalize_key" do
      it "normalizes lowercase key to uppercase" do
        secret = build(:secret, key: "my_key")
        secret.valid?
        expect(secret.key).to eq("MY_KEY")
      end
    end

    describe "before_validation :set_path" do
      it "sets path based on key and folder" do
        secret = build(:secret, key: "API_KEY")
        secret.valid?
        expect(secret.path).to be_present
      end
    end
  end

  describe "scopes" do
    let(:project) { create(:project) }
    let!(:active_secret)   { create(:secret, project: project, archived: false) }
    let!(:archived_secret) { create(:secret, project: project, archived: true, archived_at: 1.day.ago) }

    describe ".active" do
      it "returns only non-archived secrets" do
        expect(project.secrets.active).to include(active_secret)
        expect(project.secrets.active).not_to include(archived_secret)
      end
    end

    describe ".credentials" do
      let!(:credential_secret) { create(:secret, project: project, secret_type: "credential") }

      it "returns only credential type secrets" do
        expect(project.secrets.credentials).to include(credential_secret)
        expect(project.secrets.credentials).not_to include(active_secret)
      end
    end

    describe ".in_folder" do
      let(:folder) { create(:secret_folder, project: project) }
      let!(:foldered_secret) { create(:secret, project: project, secret_folder: folder) }

      it "returns secrets in the given folder" do
        expect(project.secrets.in_folder(folder.id)).to include(foldered_secret)
        expect(project.secrets.in_folder(folder.id)).not_to include(active_secret)
      end
    end

    describe ".with_tag" do
      let!(:tagged_secret) { create(:secret, project: project, tags: { "env" => "production" }) }

      it "returns secrets with the given tag key and value" do
        expect(project.secrets.with_tag("env", "production")).to include(tagged_secret)
        expect(project.secrets.with_tag("env", "production")).not_to include(active_secret)
      end
    end
  end

  describe ".normalize_key" do
    it "converts URL to uppercase key" do
      expect(Secret.normalize_key("https://api.example.com")).to be_a(String)
      expect(Secret.normalize_key("https://api.example.com")).to match(/\A[A-Z][A-Z0-9_]*\z/)
    end

    it "converts domain to uppercase key" do
      result = Secret.normalize_key("api.example.com")
      expect(result).to eq(result.upcase)
    end

    it "converts plain string to uppercase" do
      expect(Secret.normalize_key("my_secret_key")).to eq("MY_SECRET_KEY")
    end
  end

  describe "#otp_enabled?" do
    it "returns true for credential type" do
      secret = build(:secret, secret_type: "credential")
      expect(secret.otp_enabled?).to be true
    end

    it "returns true for totp type" do
      secret = build(:secret, secret_type: "totp")
      expect(secret.otp_enabled?).to be true
    end

    it "returns true for hotp type" do
      secret = build(:secret, secret_type: "hotp")
      expect(secret.otp_enabled?).to be true
    end

    it "returns false for string type" do
      secret = build(:secret, secret_type: "string")
      expect(secret.otp_enabled?).to be false
    end
  end

  describe "#credential?" do
    it "returns true when secret_type is credential" do
      secret = build(:secret, secret_type: "credential")
      expect(secret.credential?).to be true
    end

    it "returns false for other types" do
      secret = build(:secret, secret_type: "string")
      expect(secret.credential?).to be false
    end
  end

  describe "#has_versions?" do
    it "returns true when versions_count is greater than 0" do
      secret = build(:secret, versions_count: 1)
      expect(secret.has_versions?).to be true
    end

    it "returns false when versions_count is 0" do
      secret = build(:secret, versions_count: 0)
      expect(secret.has_versions?).to be false
    end
  end

  describe "#archive!" do
    let(:project) { create(:project) }
    let(:secret)  { create(:secret, project: project) }

    it "marks the secret as archived" do
      secret.archive!
      expect(secret.reload.archived).to be true
    end

    it "sets archived_at timestamp" do
      secret.archive!
      expect(secret.reload.archived_at).to be_present
    end

    it "creates an AuditLog entry" do
      expect { secret.archive! }.to change(AuditLog, :count).by(1)
    end
  end
end
