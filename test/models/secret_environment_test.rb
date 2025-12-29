# frozen_string_literal: true

require "test_helper"

class SecretEnvironmentTest < ActiveSupport::TestCase
  # ===========================================
  # Validations
  # ===========================================

  test "valid secret environment with all required attributes" do
    env = SecretEnvironment.new(
      project: projects(:acme),
      name: "Custom Environment",
      slug: "custom-env"
    )
    assert env.valid?
  end

  test "invalid without name" do
    env = SecretEnvironment.new(project: projects(:acme), slug: "test")
    assert_not env.valid?
    assert_includes env.errors[:name], "can't be blank"
  end

  test "name must be unique per project" do
    existing = secret_environments(:acme_development)
    duplicate = SecretEnvironment.new(
      project: existing.project,
      name: existing.name
    )
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:name], "has already been taken"
  end

  test "name can be duplicated across projects" do
    # Create a fresh project to test name duplication
    project1 = create_project(platform_project_id: SecureRandom.uuid, name: "Project One")
    project2 = create_project(platform_project_id: SecureRandom.uuid, name: "Project Two")

    env1 = project1.secret_environments.create!(
      name: "Custom Env",
      slug: "custom-env",
      position: 10
    )

    env2 = SecretEnvironment.new(
      project: project2,
      name: env1.name,
      slug: "custom-env",
      position: 10
    )
    assert env2.valid?, "Expected env2 to be valid, got: #{env2.errors.full_messages.join(', ')}"
  end

  test "slug must be lowercase with dashes" do
    env = SecretEnvironment.new(
      project: projects(:acme),
      name: "Test"
    )

    # Valid slugs
    env.slug = "valid-slug"
    assert env.valid?

    env.slug = "valid123"
    assert env.valid?

    env.slug = "a"
    assert env.valid?

    # Invalid slugs
    env.slug = "UPPERCASE"
    assert_not env.valid?
    assert_includes env.errors[:slug], "is invalid"

    env.slug = "has spaces"
    assert_not env.valid?

    env.slug = "has_underscores"
    assert_not env.valid?
  end

  test "slug must be unique per project" do
    existing = secret_environments(:acme_development)
    duplicate = SecretEnvironment.new(
      project: existing.project,
      name: "Different Name",
      slug: existing.slug
    )
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:slug], "has already been taken"
  end

  # ===========================================
  # Callbacks
  # ===========================================

  test "sets slug from name before validation" do
    env = SecretEnvironment.new(
      project: projects(:acme),
      name: "My Custom Environment"
    )
    env.valid?

    assert_equal "my-custom-environment", env.slug
  end

  test "does not override existing slug" do
    env = SecretEnvironment.new(
      project: projects(:acme),
      name: "Test Environment",
      slug: "custom-slug"
    )
    env.valid?

    assert_equal "custom-slug", env.slug
  end

  # ===========================================
  # Associations
  # ===========================================

  test "belongs to project" do
    env = secret_environments(:acme_development)
    assert_respond_to env, :project
    assert_equal projects(:acme), env.project
  end

  test "belongs to parent_environment optionally" do
    env = secret_environments(:acme_development)
    assert_respond_to env, :parent_environment
  end

  test "has many secret_versions" do
    env = secret_environments(:acme_development)
    assert_respond_to env, :secret_versions
    assert env.secret_versions.count >= 0
  end

  test "has many child_environments" do
    env = secret_environments(:acme_development)
    assert_respond_to env, :child_environments
  end

  test "dependent destroy removes secret_versions" do
    project = create_project
    env = project.secret_environments.find_by(slug: "development")
    secret = create_secret(project: project)
    create_secret_version(secret: secret, environment: env)

    version_ids = env.secret_versions.pluck(:id)
    assert version_ids.any?

    env.destroy!
    assert_equal 0, SecretVersion.where(id: version_ids).count
  end

  # ===========================================
  # Scopes
  # ===========================================

  test "ordered scope sorts by position" do
    project = projects(:acme)
    envs = project.secret_environments.ordered

    positions = envs.map(&:position)
    assert_equal positions, positions.sort
  end

  # ===========================================
  # Instance Methods
  # ===========================================

  test "secrets_count returns count of active secrets with current versions" do
    env = secret_environments(:acme_development)
    count = env.secrets_count

    assert count.is_a?(Integer)
    assert count >= 0
  end

  test "resolve_value returns value from current environment" do
    secret = secrets(:acme_database_url)
    env = secret_environments(:acme_development)

    # Create a mock for the secret's current_version
    mock_version = Minitest::Mock.new
    mock_version.expect :decrypt, "test_value"

    secret.stub :current_version, mock_version do
      value = env.resolve_value(secret)
      assert_equal "test_value", value
    end
  end

  test "resolve_value falls back to parent environment" do
    project = projects(:acme)
    parent_env = secret_environments(:acme_development)
    child_env = SecretEnvironment.create!(
      project: project,
      name: "Child Env",
      slug: "child-env",
      parent_environment: parent_env
    )

    secret = secrets(:acme_database_url)

    # Stub the Encryption::Encryptor.decrypt method to avoid encryption issues with test fixtures
    Encryption::Encryptor.stub :decrypt, "parent_value" do
      value = child_env.resolve_value(secret)
      # Child has no version, should fall back to parent
      assert_equal "parent_value", value
    end
  end

  test "resolve_value returns nil when no version exists" do
    project = create_project
    env = project.secret_environments.find_by(slug: "development")
    secret = create_secret(project: project)

    assert_nil env.resolve_value(secret)
  end

  test "all_secrets returns secrets with current versions" do
    env = secret_environments(:acme_development)
    secrets = env.all_secrets

    assert secrets.respond_to?(:each)
    secrets.each do |s|
      assert_equal env.project_id, s.project_id
      assert_not s.archived?
    end
  end
end
