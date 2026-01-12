# frozen_string_literal: true

require "test_helper"

class AuditLogTest < ActiveSupport::TestCase
  # ===========================================
  # Validations
  # ===========================================

  test "valid audit log with all required attributes" do
    log = AuditLog.new(
      project: projects(:acme),
      action: "read",
      resource_type: "secret",
      actor_type: "user",
      actor_id: "user_123"
    )
    assert log.valid?
  end

  test "invalid without action" do
    log = AuditLog.new(
      project: projects(:acme),
      resource_type: "secret",
      actor_type: "user"
    )
    assert_not log.valid?
    assert_includes log.errors[:action], "can't be blank"
  end

  test "invalid without resource_type" do
    log = AuditLog.new(
      project: projects(:acme),
      action: "read",
      actor_type: "user"
    )
    assert_not log.valid?
    assert_includes log.errors[:resource_type], "can't be blank"
  end

  test "invalid without actor_type" do
    log = AuditLog.new(
      project: projects(:acme),
      action: "read",
      resource_type: "secret"
    )
    assert_not log.valid?
    assert_includes log.errors[:actor_type], "can't be blank"
  end

  # ===========================================
  # Constants
  # ===========================================

  test "ACTIONS constant has correct values" do
    expected = %w[read create update delete archive rotate rollback access_granted access_denied]
    assert_equal expected, AuditLog::ACTIONS
  end

  test "RESOURCE_TYPES constant has correct values" do
    expected = %w[secret environment token policy folder]
    assert_equal expected, AuditLog::RESOURCE_TYPES
  end

  test "ACTOR_TYPES constant has correct values" do
    expected = %w[user token system]
    assert_equal expected, AuditLog::ACTOR_TYPES
  end

  # ===========================================
  # Associations
  # ===========================================

  test "belongs to project" do
    log = AuditLog.create!(
      project: projects(:acme),
      action: "create",
      resource_type: "secret",
      actor_type: "user",
      actor_id: "user_123"
    )
    assert_respond_to log, :project
    assert_equal projects(:acme), log.project
  end

  # ===========================================
  # Scopes
  # ===========================================

  test "recent scope orders by created_at desc" do
    # Create logs with different timestamps
    AuditLog.create!(project: projects(:acme), action: "read", resource_type: "secret", actor_type: "user", created_at: 2.days.ago)
    AuditLog.create!(project: projects(:acme), action: "create", resource_type: "secret", actor_type: "user", created_at: 1.day.ago)
    AuditLog.create!(project: projects(:acme), action: "update", resource_type: "secret", actor_type: "user", created_at: Time.current)

    logs = AuditLog.recent.limit(5)
    dates = logs.map(&:created_at)
    assert_equal dates, dates.sort.reverse
  end

  test "for_secret scope filters by secret" do
    secret = secrets(:acme_database_url)
    # Create a log for this secret
    AuditLog.create!(
      project: secret.project,
      action: "read",
      resource_type: "secret",
      resource_id: secret.id,
      actor_type: "user"
    )

    logs = AuditLog.for_secret(secret)
    assert logs.any?

    logs.each do |log|
      assert_equal "secret", log.resource_type
      assert_equal secret.id, log.resource_id
    end
  end

  test "by_actor scope filters by type and id" do
    log = AuditLog.create!(
      project: projects(:acme),
      action: "create",
      resource_type: "secret",
      actor_type: "user",
      actor_id: "user_admin_001"
    )

    found = AuditLog.by_actor(log.actor_type, log.actor_id)
    assert found.include?(log)
  end

  test "for_environment scope filters by environment" do
    AuditLog.create!(
      project: projects(:acme),
      action: "read",
      resource_type: "secret",
      actor_type: "user",
      environment: "development"
    )

    logs = AuditLog.for_environment("development")
    assert logs.any?
    logs.each do |log|
      assert_equal "development", log.environment
    end
  end

  # ===========================================
  # Class Methods
  # ===========================================

  test "log_access creates log for secret access with token" do
    secret = secrets(:acme_database_url)
    env = secret_environments(:acme_development)
    token = access_tokens(:acme_admin_token)

    assert_difference "AuditLog.count", 1 do
      AuditLog.log_access(secret, env, token: token, ip: "192.168.1.1", success: true)
    end

    log = AuditLog.recent.first
    assert_equal secret.project, log.project
    assert_equal "read", log.action
    assert_equal "secret", log.resource_type
    assert_equal secret.id, log.resource_id
    assert_equal "token", log.actor_type
    assert_equal token.id, log.actor_id
    assert_equal "192.168.1.1", log.ip_address
    assert log.success?
  end

  test "log_access creates log for denied access" do
    secret = secrets(:acme_database_url)
    env = secret_environments(:acme_development)
    token = access_tokens(:acme_readonly_token)

    AuditLog.log_access(secret, env, token: token, success: false, error: "Permission denied")

    log = AuditLog.recent.first
    assert_equal "access_denied", log.action
    assert_not log.success?
    assert_equal "Permission denied", log.error_message
  end

  test "log_access creates generic log without secret" do
    project = projects(:acme)

    assert_difference "AuditLog.count", 1 do
      AuditLog.log_access(nil, nil,
        project: project,
        action: "export",
        resource_type: "project",
        resource_id: project.id,
        actor_type: "user",
        actor_id: "user_123",
        actor_name: "Test User",
        ip_address: "10.0.0.1"
      )
    end

    log = AuditLog.recent.first
    assert_equal project, log.project
    assert_equal "export", log.action
    assert_equal "project", log.resource_type
  end

  # ===========================================
  # Instance Methods
  # ===========================================

  test "secret returns associated secret" do
    secret = secrets(:acme_database_url)
    log = AuditLog.create!(
      project: secret.project,
      action: "read",
      resource_type: "secret",
      resource_id: secret.id,
      actor_type: "user",
      actor_id: "user_123"
    )

    assert_respond_to log, :secret
    assert_equal secret, log.secret
  end

  test "secret returns nil for non-secret resource_type" do
    log = AuditLog.new(
      project: projects(:acme),
      action: "create",
      resource_type: "token",
      resource_id: "some_id",
      actor_type: "user"
    )

    assert_nil log.secret
  end

  test "secret_key extracts key from resource_path" do
    log = AuditLog.new(
      project: projects(:acme),
      action: "read",
      resource_type: "secret",
      resource_path: "/folder/DATABASE_URL",
      actor_type: "user"
    )

    assert_equal "DATABASE_URL", log.secret_key
  end

  test "secret_key works with paths without folder" do
    log = AuditLog.new(
      project: projects(:acme),
      action: "read",
      resource_type: "secret",
      resource_path: "/API_KEY",
      actor_type: "user"
    )

    assert_equal "API_KEY", log.secret_key
  end

  test "secret_key returns nil for non-secret resource_type" do
    log = AuditLog.new(
      project: projects(:acme),
      action: "create",
      resource_type: "token",
      resource_path: "/some/path",
      actor_type: "user"
    )

    assert_nil log.secret_key
  end

  test "secret_key returns nil when resource_path is blank" do
    log = AuditLog.new(
      project: projects(:acme),
      action: "read",
      resource_type: "secret",
      resource_path: nil,
      actor_type: "user"
    )

    assert_nil log.secret_key
  end

  # ===========================================
  # Immutability (tested by stubbing Rails.env to simulate production)
  # In test environment, immutability is bypassed for fixture cleanup
  # ===========================================

  test "readonly? returns true for persisted records in production" do
    log = AuditLog.create!(
      project: projects(:acme),
      action: "create",
      resource_type: "secret",
      actor_type: "user",
      actor_id: "user_123"
    )

    # Stub Rails.env to simulate production behavior
    Rails.stub(:env, ActiveSupport::StringInquirer.new("production")) do
      assert log.readonly?
    end
  end

  test "readonly? returns false for new records" do
    log = AuditLog.new
    assert_not log.readonly?
  end

  test "destroy raises error in production" do
    log = AuditLog.create!(
      project: projects(:acme),
      action: "create",
      resource_type: "secret",
      actor_type: "user",
      actor_id: "user_123"
    )

    Rails.stub(:env, ActiveSupport::StringInquirer.new("production")) do
      assert_raises ActiveRecord::ReadOnlyRecord do
        log.destroy
      end
    end
  end

  test "delete raises error in production" do
    log = AuditLog.create!(
      project: projects(:acme),
      action: "create",
      resource_type: "secret",
      actor_type: "user",
      actor_id: "user_123"
    )

    Rails.stub(:env, ActiveSupport::StringInquirer.new("production")) do
      assert_raises ActiveRecord::ReadOnlyRecord do
        log.delete
      end
    end
  end

  test "cannot update persisted audit log in production" do
    log = AuditLog.create!(
      project: projects(:acme),
      action: "create",
      resource_type: "secret",
      actor_type: "user",
      actor_id: "user_123"
    )

    Rails.stub(:env, ActiveSupport::StringInquirer.new("production")) do
      assert_raises ActiveRecord::ReadOnlyRecord do
        log.update!(action: "different_action")
      end
    end
  end

  test "allows deletion in test environment for fixture cleanup" do
    # Verify we can delete in test environment (needed for transactional fixtures)
    log = AuditLog.create!(
      project: projects(:acme),
      action: "test",
      resource_type: "secret",
      actor_type: "user",
      actor_id: "test_user"
    )

    assert_nothing_raised do
      log.destroy
    end
  end
end
