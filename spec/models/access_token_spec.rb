require "rails_helper"

RSpec.describe AccessToken, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:project) }
  end

  describe "validations" do
    subject { build(:access_token) }

    it { is_expected.to validate_presence_of(:name) }
    it "auto-generates token_digest via generate_token callback" do
      token = create(:access_token)
      expect(token.token_digest).to be_present
    end

    it "enforces uniqueness of token_digest scoped to project" do
      existing = create(:access_token)
      duplicate = build(:access_token, project: existing.project, token_digest: existing.token_digest)
      duplicate.valid?
      expect(duplicate.errors[:token_digest]).to be_present
    end
  end

  describe "callbacks" do
    describe "before_validation :generate_token on create" do
      it "sets plain_token on new record" do
        token = build(:access_token)
        token.valid?
        expect(token.plain_token).to be_present
      end

      it "sets token_prefix" do
        token = create(:access_token)
        expect(token.token_prefix).to be_present
      end

      it "sets token_digest" do
        token = create(:access_token)
        expect(token.token_digest).to be_present
      end

      it "does not regenerate token on update" do
        token = create(:access_token)
        original_digest = token.token_digest
        token.update!(name: "Updated Name")
        expect(token.token_digest).to eq(original_digest)
      end
    end
  end

  describe "attr_accessor :plain_token" do
    it "exposes plain_token as a virtual attribute" do
      token = build(:access_token)
      token.plain_token = "test_plain_value"
      expect(token.plain_token).to eq("test_plain_value")
    end
  end

  describe "scopes" do
    let(:project) { create(:project) }

    describe ".active" do
      let!(:active_token)   { create(:access_token, project: project, active: true, revoked_at: nil, expires_at: 1.day.from_now) }
      let!(:revoked_token)  { create(:access_token, project: project, active: false, revoked_at: Time.current) }
      let!(:expired_token)  { create(:access_token, project: project, active: true, expires_at: 1.day.ago) }

      it "returns active non-revoked non-expired tokens" do
        expect(AccessToken.active).to include(active_token)
        expect(AccessToken.active).not_to include(revoked_token)
        expect(AccessToken.active).not_to include(expired_token)
      end
    end
  end

  describe ".authenticate" do
    let!(:token) { create(:access_token) }

    it "finds a token by its raw plain_token value" do
      raw = token.plain_token
      # plain_token is only available at creation time; store it for this test
      found = AccessToken.authenticate(raw)
      expect(found).to eq(token)
    end

    it "returns nil for an invalid token" do
      expect(AccessToken.authenticate("invalid_token_string")).to be_nil
    end

    it "updates last_used_at when found" do
      raw = token.plain_token
      expect { AccessToken.authenticate(raw) }.to change { token.reload.last_used_at }
    end
  end

  describe "#can_access?" do
    let(:project)     { create(:project) }
    let(:environment) { project.secret_environments.find_by(name: "Development") }
    let(:secret)      { create(:secret, project: project) }
    let(:token)       { create(:access_token, project: project, active: true, revoked_at: nil, expires_at: nil, permissions: ["read"]) }

    it "returns true for an active token with the required permission" do
      expect(token.can_access?(secret, environment, permission: "read")).to be true
    end

    it "returns false for a revoked token" do
      token.update!(active: false, revoked_at: Time.current)
      expect(token.can_access?(secret, environment, permission: "read")).to be false
    end

    it "returns false for an expired token" do
      token.update!(expires_at: 1.day.ago)
      expect(token.can_access?(secret, environment, permission: "read")).to be false
    end
  end

  describe "#revoke!" do
    let(:token) { create(:access_token) }

    it "sets active to false" do
      token.revoke!(by: "admin")
      expect(token.reload.active).to be false
    end

    it "sets revoked_at timestamp" do
      token.revoke!(by: "admin")
      expect(token.reload.revoked_at).to be_present
    end

    it "sets revoked_by" do
      token.revoke!(by: "admin")
      expect(token.reload.revoked_by).to eq("admin")
    end
  end

  describe "#regenerate!" do
    let(:token) { create(:access_token) }

    it "updates token_prefix and token_digest" do
      old_prefix = token.token_prefix
      old_digest = token.token_digest
      token.regenerate!
      expect(token.reload.token_prefix).not_to eq(old_prefix)
      expect(token.reload.token_digest).not_to eq(old_digest)
    end

    it "makes plain_token available" do
      token.regenerate!
      expect(token.plain_token).to be_present
    end
  end

  describe "#expired?" do
    it "returns false when expires_at is nil" do
      token = build(:access_token, expires_at: nil)
      expect(token.expired?).to be false
    end

    it "returns true when expires_at is in the past" do
      token = build(:access_token, expires_at: 1.hour.ago)
      expect(token.expired?).to be true
    end

    it "returns false when expires_at is in the future" do
      token = build(:access_token, expires_at: 1.hour.from_now)
      expect(token.expired?).to be false
    end
  end

  describe "#revoked?" do
    it "returns true when revoked_at is present" do
      token = build(:access_token, revoked_at: Time.current)
      expect(token.revoked?).to be true
    end

    it "returns false when revoked_at is nil" do
      token = build(:access_token, revoked_at: nil)
      expect(token.revoked?).to be false
    end
  end

  describe "#has_permission?" do
    it "returns true when permission is in the permissions list" do
      token = build(:access_token, permissions: ["read", "write"])
      expect(token.has_permission?("read")).to be true
      expect(token.has_permission?("write")).to be true
    end

    it "returns false when permission is not in the permissions list" do
      token = build(:access_token, permissions: ["read"])
      expect(token.has_permission?("delete")).to be false
    end
  end
end
