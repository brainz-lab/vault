# frozen_string_literal: true

require "test_helper"

class SecretVersionTest < ActiveSupport::TestCase
  # ===========================================
  # Validations
  # ===========================================

  test "valid secret version with all required attributes" do
    secret = secrets(:acme_database_url)
    env = secret_environments(:acme_development)

    version = SecretVersion.new(
      secret: secret,
      secret_environment: env,
      version: 99,
      encrypted_value: "encrypted_data",
      encryption_iv: "random_iv",
      encryption_key_id: "key_001"
    )
    assert version.valid?
  end

  test "invalid without version" do
    version = SecretVersion.new(
      secret: secrets(:acme_database_url),
      secret_environment: secret_environments(:acme_development),
      encrypted_value: "data",
      encryption_iv: "iv"
    )
    assert_not version.valid?
    assert_includes version.errors[:version], "can't be blank"
  end

  test "version must be greater than 0" do
    version = SecretVersion.new(
      secret: secrets(:acme_database_url),
      secret_environment: secret_environments(:acme_development),
      version: 0,
      encrypted_value: "data",
      encryption_iv: "iv"
    )
    assert_not version.valid?
    assert_includes version.errors[:version], "must be greater than 0"

    version.version = -1
    assert_not version.valid?
  end

  test "invalid without encrypted_value" do
    version = SecretVersion.new(
      secret: secrets(:acme_database_url),
      secret_environment: secret_environments(:acme_development),
      version: 1,
      encryption_iv: "iv"
    )
    assert_not version.valid?
    assert_includes version.errors[:encrypted_value], "can't be blank"
  end

  test "invalid without encryption_iv" do
    version = SecretVersion.new(
      secret: secrets(:acme_database_url),
      secret_environment: secret_environments(:acme_development),
      version: 1,
      encrypted_value: "data"
    )
    assert_not version.valid?
    assert_includes version.errors[:encryption_iv], "can't be blank"
  end

  # ===========================================
  # Associations
  # ===========================================

  test "belongs to secret" do
    version = secret_versions(:acme_db_url_v1)
    assert_respond_to version, :secret
    assert_equal secrets(:acme_database_url), version.secret
  end

  test "belongs to secret_environment" do
    version = secret_versions(:acme_db_url_v1)
    assert_respond_to version, :secret_environment
    assert_equal secret_environments(:acme_development), version.secret_environment
  end

  # ===========================================
  # Instance Methods
  # ===========================================

  test "expired? returns true when expires_at is in the past" do
    version = secret_versions(:acme_db_url_v1)

    version.expires_at = 1.day.ago
    assert version.expired?

    version.expires_at = 1.day.from_now
    assert_not version.expired?

    version.expires_at = nil
    assert_not version.expired?
  end

  test "value_preview returns masked value for long secrets" do
    version = secret_versions(:acme_db_url_v1)

    # Mock decrypt to return a known value
    version.stub :decrypt, "postgresql://user:password@localhost/db" do
      preview = version.value_preview
      assert preview.include?("...")
      assert_equal 4, preview.split("...").first.length
      assert_equal 4, preview.split("...").last.length
    end
  end

  test "value_preview returns dots for short secrets" do
    version = secret_versions(:acme_db_url_v1)

    version.stub :decrypt, "short" do
      assert_equal "••••••••", version.value_preview
    end
  end

  test "value_preview returns dots on decrypt error" do
    version = secret_versions(:acme_db_url_v1)

    version.stub :decrypt, -> { raise "Decryption failed" } do
      assert_equal "••••••••", version.value_preview
    end
  end

  # ===========================================
  # Callbacks
  # ===========================================

  test "audit_creation creates audit log on create" do
    secret = secrets(:acme_database_url)
    env = secret_environments(:acme_development)

    # Skip the actual audit creation by using a transaction we can inspect
    assert_difference "AuditLog.count", 1 do
      SecretVersion.create!(
        secret: secret,
        secret_environment: env,
        version: 999,
        encrypted_value: "test_encrypted",
        encryption_iv: "test_iv",
        encryption_key_id: "test_key"
      )
    end

    log = AuditLog.last
    assert_equal "secret", log.resource_type
    assert_equal secret.id, log.resource_id
  end

  test "audit_creation uses create action for version 1" do
    project = create_project
    secret = create_secret(project: project)
    env = project.secret_environments.find_by(slug: "development")

    SecretVersion.create!(
      secret: secret,
      secret_environment: env,
      version: 1,
      encrypted_value: "test",
      encryption_iv: "iv",
      encryption_key_id: "key"
    )

    log = AuditLog.last
    assert_equal "create", log.action
  end

  test "audit_creation uses update action for version > 1" do
    project = create_project
    secret = create_secret(project: project)
    env = project.secret_environments.find_by(slug: "development")

    SecretVersion.create!(
      secret: secret,
      secret_environment: env,
      version: 2,
      encrypted_value: "test",
      encryption_iv: "iv",
      encryption_key_id: "key"
    )

    log = AuditLog.last
    assert_equal "update", log.action
  end
end
