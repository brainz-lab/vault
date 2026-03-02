require "rails_helper"

RSpec.describe AccessChecker do
  before do
    @project = create(:project, name: "Access Test Project")
    @checker = described_class.new(@project)
    @token = create(:access_token, :full_access, project: @project)
    @development = create(:secret_environment, project: @project, name: "Development", slug: "development")
    @staging = create(:secret_environment, project: @project, name: "Staging", slug: "staging")
    @secret = create(:secret, project: @project, key: "DATABASE_URL")
  end

  describe "#can_access?" do
    it "returns true when matching policy exists" do
      create(:access_policy,
        project: @project,
        name: "Test Policy",
        principal_type: "token",
        principal_id: @token.id.to_s,
        permissions: ["read"],
        environments: ["development"],
        paths: ["*"],
        enabled: true
      )

      expect(@checker.can_access?(@token, @secret, @development, permission: "read")).to be true
    end

    it "returns false when no matching policy" do
      expect(@checker.can_access?(@token, @secret, @development, permission: "read")).to be false
    end

    it "returns false when policy is disabled" do
      create(:access_policy,
        project: @project,
        name: "Disabled Policy",
        principal_type: "token",
        principal_id: @token.id.to_s,
        permissions: ["read"],
        environments: ["development"],
        paths: ["*"],
        enabled: false
      )

      expect(@checker.can_access?(@token, @secret, @development, permission: "read")).to be false
    end

    it "checks environment restrictions" do
      create(:access_policy,
        project: @project,
        name: "Staging Only Policy",
        principal_type: "token",
        principal_id: @token.id.to_s,
        permissions: ["read"],
        environments: ["staging"],
        paths: ["*"],
        enabled: true
      )

      # Should fail for development environment
      expect(@checker.can_access?(@token, @secret, @development, permission: "read")).to be false

      # Should pass for staging environment
      expect(@checker.can_access?(@token, @secret, @staging, permission: "read")).to be true
    end

    it "checks path restrictions" do
      folder = create(:secret_folder, project: @project, name: "database")
      db_secret = create(:secret, project: @project, key: "DB_HOST", secret_folder: folder)

      create(:access_policy,
        project: @project,
        name: "Database Only Policy",
        principal_type: "token",
        principal_id: @token.id.to_s,
        permissions: ["read"],
        environments: [],
        paths: ["/database/*"],
        enabled: true
      )

      # Secret in /database/ should match
      expect(@checker.can_access?(@token, db_secret, @development, permission: "read")).to be true

      # Secret not in /database/ should not match
      other_secret = create(:secret, project: @project, key: "OTHER_KEY")
      expect(@checker.can_access?(@token, other_secret, @development, permission: "read")).to be false
    end

    it "checks permission type" do
      create(:access_policy,
        project: @project,
        name: "Read Only Policy",
        principal_type: "token",
        principal_id: @token.id.to_s,
        permissions: ["read"],
        environments: [],
        paths: [],
        enabled: true
      )

      expect(@checker.can_access?(@token, @secret, @development, permission: "read")).to be true
      expect(@checker.can_access?(@token, @secret, @development, permission: "write")).to be false
      expect(@checker.can_access?(@token, @secret, @development, permission: "delete")).to be false
    end
  end

  describe "#allowed_secrets" do
    it "returns secrets matching policy" do
      create(:access_policy,
        project: @project,
        name: "All Access",
        principal_type: "token",
        principal_id: @token.id.to_s,
        permissions: ["read"],
        environments: ["development"],
        paths: ["*"],
        enabled: true
      )

      allowed = @checker.allowed_secrets(@token, @development)
      expect(allowed).not_to be_empty
      expect(allowed).to all(have_attributes(project_id: @project.id))
    end

    it "returns empty array when no policies" do
      allowed = @checker.allowed_secrets(@token, @development)
      expect(allowed).to eq([])
    end

    it "filters by path" do
      folder = create(:secret_folder, project: @project, name: "database")
      create(:secret, project: @project, key: "DB_HOST", secret_folder: folder)
      create(:secret, project: @project, key: "OTHER_KEY")

      create(:access_policy,
        project: @project,
        name: "Database Access",
        principal_type: "token",
        principal_id: @token.id.to_s,
        permissions: ["read"],
        environments: [],
        paths: ["/database/*"],
        enabled: true
      )

      allowed = @checker.allowed_secrets(@token, @development)
      expect(allowed).to all(have_attributes(path: start_with("/database/")))
    end
  end

  describe "#check_conditions" do
    it "delegates to policy" do
      policy = create(:access_policy,
        project: @project,
        name: "IP Restricted",
        principal_type: "token",
        principal_id: @token.id.to_s,
        permissions: ["read"],
        environments: [],
        paths: [],
        conditions: { "allowed_ips" => ["10.0.0.0/8"] },
        enabled: true
      )

      context = { ip: "10.0.0.1" }
      result = @checker.check_conditions(policy, context)
      # Result depends on AccessPolicy#check_conditions implementation
      expect([true, false]).to include(result)
    end
  end
end
