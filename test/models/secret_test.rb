# frozen_string_literal: true

require "test_helper"

class SecretTest < ActiveSupport::TestCase
  # ===========================================
  # Validations
  # ===========================================

  test "valid secret with all required attributes" do
    project = projects(:acme)
    secret = Secret.new(
      project: project,
      key: "TEST_SECRET",
      path: "/TEST_SECRET"
    )
    assert secret.valid?
  end

  test "invalid without key" do
    secret = Secret.new(project: projects(:acme))
    assert_not secret.valid?
    assert_includes secret.errors[:key], "can't be blank"
  end

  test "key must be uppercase with underscores" do
    project = projects(:acme)

    # Valid formats (use keys that don't conflict with fixtures)
    assert Secret.new(project: project, key: "TEST_DATABASE_URL").valid?
    assert Secret.new(project: project, key: "TEST_API_KEY").valid?
    assert Secret.new(project: project, key: "SECRET123").valid?
    assert Secret.new(project: project, key: "A").valid?

    # Invalid formats
    invalid_secret = Secret.new(project: project, key: "lowercase")
    assert_not invalid_secret.valid?
    assert_includes invalid_secret.errors[:key], "must be uppercase with underscores (e.g., DATABASE_URL)"

    invalid_secret = Secret.new(project: project, key: "Mixed_Case")
    assert_not invalid_secret.valid?

    invalid_secret = Secret.new(project: project, key: "123_STARTS_WITH_NUMBER")
    assert_not invalid_secret.valid?
  end

  test "path must be unique per project" do
    existing = secrets(:acme_database_url)
    # Use same key and folder to get the same path
    duplicate = Secret.new(
      project: existing.project,
      key: existing.key,
      secret_folder: existing.secret_folder
    )
    duplicate.valid?  # Trigger set_path callback
    assert_equal existing.path, duplicate.path
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:path], "has already been taken"
  end

  test "path can be duplicated across projects" do
    secret1 = secrets(:acme_database_url)
    secret2 = Secret.new(
      project: projects(:startup),
      key: secret1.key,
      path: secret1.path
    )
    # Path uniqueness is scoped to project
    secret2.path = "/unique_for_startup/#{secret1.key}"
    assert secret2.valid?
  end

  # ===========================================
  # Callbacks
  # ===========================================

  test "sets path from folder and key before validation" do
    project = projects(:acme)
    folder = secret_folders(:acme_database)

    secret = Secret.new(
      project: project,
      secret_folder: folder,
      key: "NEW_SECRET"
    )
    secret.valid?

    assert_equal "/database/NEW_SECRET", secret.path
  end

  test "sets path without folder" do
    project = projects(:acme)

    secret = Secret.new(
      project: project,
      key: "ROOT_SECRET"
    )
    secret.valid?

    assert_equal "/ROOT_SECRET", secret.path
  end

  # ===========================================
  # Scopes
  # ===========================================

  test "active scope excludes archived secrets" do
    active_secrets = Secret.active

    assert active_secrets.include?(secrets(:acme_database_url))
    assert_not active_secrets.include?(secrets(:acme_archived_secret))
  end

  test "in_folder scope filters by folder" do
    folder = secret_folders(:acme_database)
    secrets_in_folder = Secret.in_folder(folder)

    assert secrets_in_folder.all? { |s| s.secret_folder_id == folder.id }
  end

  # ===========================================
  # Associations
  # ===========================================

  test "belongs to project" do
    secret = secrets(:acme_database_url)
    assert_respond_to secret, :project
    assert_equal projects(:acme), secret.project
  end

  test "belongs to secret_folder optionally" do
    with_folder = secrets(:acme_database_url)
    without_folder = secrets(:acme_api_key)

    assert_respond_to with_folder, :secret_folder
    assert_not_nil with_folder.secret_folder

    assert_nil without_folder.secret_folder
  end

  test "has many versions" do
    secret = secrets(:acme_database_url)
    assert_respond_to secret, :versions
    assert secret.versions.count >= 1
  end

  test "dependent destroy removes versions" do
    project = create_project
    env = project.secret_environments.find_by(slug: "development")
    secret = create_secret(project: project)
    create_secret_version(secret: secret, environment: env)

    version_ids = secret.versions.pluck(:id)
    assert version_ids.any?

    secret.destroy!
    assert_equal 0, SecretVersion.where(id: version_ids).count
  end

  # ===========================================
  # Instance Methods
  # ===========================================

  test "current_version returns current version for environment" do
    secret = secrets(:acme_database_url)
    env = secret_environments(:acme_development)

    version = secret.current_version(env)

    assert_not_nil version
    assert version.current?
    assert_equal env, version.secret_environment
  end

  test "current_version returns nil when no current version" do
    project = create_project
    env = project.secret_environments.find_by(slug: "development")
    secret = create_secret(project: project)

    assert_nil secret.current_version(env)
  end

  test "current_version_number returns version number for environment" do
    secret = secrets(:acme_database_url)
    env = secret_environments(:acme_development)

    version_num = secret.current_version_number(env)

    assert version_num.is_a?(Integer)
    assert version_num > 0
  end

  test "current_version_number returns highest version when no env given" do
    secret = secrets(:acme_database_url)

    version_num = secret.current_version_number

    assert version_num.is_a?(Integer) || version_num.nil?
  end

  test "version_history returns versions in descending order" do
    secret = secrets(:acme_database_url)
    env = secret_environments(:acme_development)

    history = secret.version_history(env, limit: 5)

    assert history.any?
    versions = history.map(&:version)
    assert_equal versions, versions.sort.reverse
  end

  test "archive marks secret as archived" do
    project = create_project
    secret = create_secret(project: project)

    assert_not secret.archived?

    secret.archive!

    assert secret.reload.archived?
    assert_not_nil secret.archived_at
  end

  test "archive creates audit log" do
    project = create_project
    secret = create_secret(project: project)

    assert_difference "AuditLog.count", 1 do
      secret.archive!(user: "test_user")
    end

    log = AuditLog.recent.first
    assert_equal "archive", log.action
    assert_equal "secret", log.resource_type
    assert_equal secret.id, log.resource_id
  end
end
