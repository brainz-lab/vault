require "rails_helper"

RSpec.describe AuditLog, type: :model do
  describe "constants" do
    it "defines ACTIONS" do
      expect(AuditLog::ACTIONS).to eq(%w[read create update delete archive rotate rollback access_granted access_denied])
    end

    it "defines RESOURCE_TYPES" do
      expect(AuditLog::RESOURCE_TYPES).to eq(%w[secret environment token policy folder])
    end

    it "defines ACTOR_TYPES" do
      expect(AuditLog::ACTOR_TYPES).to eq(%w[user token system])
    end
  end

  describe "associations" do
    it { is_expected.to belong_to(:project) }
  end

  describe "validations" do
    subject { build(:audit_log) }

    it { is_expected.to validate_presence_of(:action) }
    it { is_expected.to validate_presence_of(:resource_type) }
    it { is_expected.to validate_presence_of(:actor_type) }
  end

  describe "scopes" do
    let(:project) { create(:project) }
    let(:secret)  { create(:secret, project: project) }
    let(:environment) { project.secret_environments.find_by(name: "Development") }

    describe ".recent" do
      let!(:older_log)  { create(:audit_log, project: project, created_at: 2.days.ago) }
      let!(:recent_log) { create(:audit_log, project: project, created_at: 1.hour.ago) }

      it "returns logs in descending created_at order" do
        logs = AuditLog.recent
        expect(logs.first.created_at).to be >= logs.last.created_at
      end
    end

    describe ".for_secret" do
      let!(:secret_log) { create(:audit_log, project: project, resource_type: "secret", resource_id: secret.id, resource_path: secret.path) }
      let!(:other_log)  { create(:audit_log, project: project, resource_path: "/OTHER_KEY") }

      it "returns logs matching the given secret path" do
        expect(AuditLog.for_secret(secret.path)).to include(secret_log)
        expect(AuditLog.for_secret(secret.path)).not_to include(other_log)
      end
    end

    describe ".by_actor" do
      let!(:token_log)  { create(:audit_log, project: project, actor_type: "token", actor_id: "token-1") }
      let!(:user_log)   { create(:audit_log, project: project, actor_type: "user",  actor_id: "user-1") }

      it "returns logs matching the given actor type and id" do
        expect(AuditLog.by_actor("token", "token-1")).to include(token_log)
        expect(AuditLog.by_actor("token", "token-1")).not_to include(user_log)
      end
    end

    describe ".for_environment" do
      let!(:env_log)   { create(:audit_log, project: project, environment: environment.slug) }
      let!(:other_log) { create(:audit_log, project: project, environment: "production") }

      it "returns logs matching the given environment slug" do
        expect(AuditLog.for_environment(environment.slug)).to include(env_log)
        expect(AuditLog.for_environment(environment.slug)).not_to include(other_log)
      end
    end
  end

  describe ".log_access" do
    let(:project)     { create(:project) }
    let(:environment) { project.secret_environments.find_by(name: "Development") }
    let(:secret)      { create(:secret, project: project) }
    let(:token)       { create(:access_token, project: project) }

    it "creates an audit log entry" do
      expect {
        AuditLog.log_access(secret, environment, token: token, ip: "127.0.0.1", success: true)
      }.to change(AuditLog, :count).by(1)
    end

    it "sets the action to read on success" do
      log = AuditLog.log_access(secret, environment, token: token, ip: "127.0.0.1", success: true)
      expect(log.action).to eq("read")
    end

    it "sets the action to access_denied on failure" do
      log = AuditLog.log_access(secret, environment, token: token, ip: "127.0.0.1", success: false)
      expect(log.action).to eq("access_denied")
    end

    it "records the remote IP" do
      log = AuditLog.log_access(secret, environment, token: token, ip: "10.0.0.5", success: true)
      expect(log.ip_address).to eq("10.0.0.5")
    end
  end

  describe "#secret_key" do
    it "extracts the key segment from resource_path" do
      log = build(:audit_log, resource_path: "/DB_PASSWORD")
      expect(log.secret_key).to eq("DB_PASSWORD")
    end

    it "returns the last path segment for nested paths" do
      log = build(:audit_log, resource_path: "/configs/DB_PASSWORD")
      expect(log.secret_key).to eq("DB_PASSWORD")
    end
  end

  describe "#readonly?" do
    it "returns false in the test environment" do
      log = build(:audit_log)
      expect(log.readonly?).to be false
    end
  end

  describe "#destroy" do
    context "in the test environment" do
      it "does not raise ReadOnlyRecord (DB-level rules prevent actual deletion)" do
        log = create(:audit_log)
        expect { log.destroy }.not_to raise_error
      end
    end
  end
end
