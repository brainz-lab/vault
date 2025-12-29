# frozen_string_literal: true

require "test_helper"

class ProjectTest < ActiveSupport::TestCase
  # ===========================================
  # Validations
  # ===========================================

  test "valid project with all required attributes" do
    project = Project.new(
      platform_project_id: SecureRandom.uuid,
      name: "Test Project",
      environment: "live"
    )
    assert project.valid?
  end

  test "invalid without platform_project_id - auto-generates if missing" do
    project = Project.new(name: "Test")
    # before_validation generates platform_project_id if missing
    assert project.valid?
    assert_not_nil project.platform_project_id
  end

  test "platform_project_id must be unique" do
    existing = projects(:acme)
    duplicate = Project.new(
      platform_project_id: existing.platform_project_id,
      name: "Duplicate"
    )
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:platform_project_id], "has already been taken"
  end

  test "api_key must be unique" do
    existing = projects(:acme)
    # Create a project first
    new_project = create_project
    # Try to set the same api_key
    new_project.api_key = existing.api_key
    assert_not new_project.valid?
    assert_includes new_project.errors[:api_key], "has already been taken"
  end

  test "ingest_key must be unique" do
    existing = projects(:acme)
    new_project = create_project
    new_project.ingest_key = existing.ingest_key
    assert_not new_project.valid?
    assert_includes new_project.errors[:ingest_key], "has already been taken"
  end

  # ===========================================
  # Callbacks
  # ===========================================

  test "generates api_key on create" do
    project = create_project
    assert_not_nil project.api_key
    assert project.api_key.start_with?("vlt_api_")
    assert_equal 40, project.api_key.length  # vlt_api_ (8) + hex(16) (32)
  end

  test "generates ingest_key on create" do
    project = create_project
    assert_not_nil project.ingest_key
    assert project.ingest_key.start_with?("vlt_ingest_")
    assert_equal 43, project.ingest_key.length  # vlt_ingest_ (11) + hex(16) (32)
  end

  test "creates default environments on create" do
    project = create_project
    environments = project.secret_environments.order(:position)

    assert_equal 3, environments.count
    assert_equal "Development", environments[0].name
    assert_equal "development", environments[0].slug
    assert_equal "Staging", environments[1].name
    assert_equal "staging", environments[1].slug
    assert_equal "Production", environments[2].name
    assert_equal "production", environments[2].slug
    assert environments[2].protected?
  end

  test "does not regenerate keys on update" do
    project = create_project
    original_api_key = project.api_key
    original_ingest_key = project.ingest_key

    project.update!(name: "Updated Name")

    assert_equal original_api_key, project.api_key
    assert_equal original_ingest_key, project.ingest_key
  end

  # ===========================================
  # Associations
  # ===========================================

  test "has many secret_environments" do
    project = projects(:acme)
    assert_respond_to project, :secret_environments
    assert project.secret_environments.count >= 3
  end

  test "has many secrets" do
    project = projects(:acme)
    assert_respond_to project, :secrets
    assert project.secrets.count > 0
  end

  test "has many access_tokens" do
    project = projects(:acme)
    assert_respond_to project, :access_tokens
    assert project.access_tokens.count > 0
  end

  test "has many access_policies" do
    project = projects(:acme)
    assert_respond_to project, :access_policies
    assert project.access_policies.count > 0
  end

  test "has many audit_logs" do
    project = projects(:acme)
    # Create an audit log for this project
    AuditLog.create!(
      project: project,
      action: "read",
      resource_type: "secret",
      actor_type: "user",
      actor_id: "user_123"
    )
    assert_respond_to project, :audit_logs
    assert project.audit_logs.count > 0
  end

  test "has many encryption_keys" do
    project = projects(:acme)
    assert_respond_to project, :encryption_keys
    assert project.encryption_keys.count > 0
  end

  test "has many secret_folders" do
    project = projects(:acme)
    assert_respond_to project, :secret_folders
    assert project.secret_folders.count > 0
  end

  test "dependent destroy removes secret_environments" do
    project = create_project
    env_count = project.secret_environments.count
    assert env_count > 0

    project.destroy!
    assert_equal 0, SecretEnvironment.where(project_id: project.id).count
  end

  test "dependent destroy removes secrets" do
    # Create a fresh project with a secret (not using fixtures to avoid FK issues)
    project = create_project
    secret = create_secret(project: project, key: "TEST_SECRET")
    secret_id = secret.id

    project.destroy!
    assert_equal 0, Secret.where(id: secret_id).count
  end

  # ===========================================
  # Class Methods
  # ===========================================

  test "find_or_create_for_platform! finds existing project" do
    existing = projects(:acme)
    found = Project.find_or_create_for_platform!(
      platform_project_id: existing.platform_project_id
    )
    assert_equal existing.id, found.id
  end

  test "find_or_create_for_platform! creates new project" do
    new_platform_id = SecureRandom.uuid

    assert_difference "Project.count", 1 do
      project = Project.find_or_create_for_platform!(
        platform_project_id: new_platform_id,
        name: "Brand New Project",
        environment: "production"
      )
      assert_equal new_platform_id, project.platform_project_id
      assert_equal "Brand New Project", project.name
      assert_equal "production", project.environment
    end
  end

  test "find_or_create_for_platform! uses default name if not provided" do
    new_platform_id = SecureRandom.uuid

    project = Project.find_or_create_for_platform!(
      platform_project_id: new_platform_id
    )
    assert_equal "Project #{new_platform_id}", project.name
  end

  test "find_by_api_key finds project by api_key" do
    project = projects(:acme)
    found = Project.find_by_api_key(project.api_key)
    assert_equal project.id, found.id
  end

  test "find_by_api_key finds project by ingest_key" do
    project = projects(:acme)
    found = Project.find_by_api_key(project.ingest_key)
    assert_equal project.id, found.id
  end

  test "find_by_api_key returns nil for unknown key" do
    assert_nil Project.find_by_api_key("unknown_key_12345")
  end

  test "find_by_api_key returns nil for nil key" do
    assert_nil Project.find_by_api_key(nil)
  end

  test "find_by_api_key returns nil for blank key" do
    assert_nil Project.find_by_api_key("")
  end

  # ===========================================
  # Key Generation
  # ===========================================

  test "api_key format is correct" do
    project = create_project
    assert_match /\Avlt_api_[a-f0-9]{32}\z/, project.api_key
  end

  test "ingest_key format is correct" do
    project = create_project
    assert_match /\Avlt_ingest_[a-f0-9]{32}\z/, project.ingest_key
  end

  test "api_keys are unique across projects" do
    project1 = create_project
    project2 = create_project

    assert_not_equal project1.api_key, project2.api_key
    assert_not_equal project1.ingest_key, project2.ingest_key
  end
end
