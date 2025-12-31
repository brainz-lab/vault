# frozen_string_literal: true

require "test_helper"

class AccessPolicyTest < ActiveSupport::TestCase
  # ===========================================
  # Validations
  # ===========================================

  test "valid access policy with all required attributes" do
    policy = AccessPolicy.new(
      project: projects(:acme),
      name: "Test Policy",
      principal_type: "user",
      principal_id: "user_123"
    )
    assert policy.valid?
  end

  test "invalid without name" do
    policy = AccessPolicy.new(
      project: projects(:acme),
      principal_type: "user"
    )
    assert_not policy.valid?
    assert_includes policy.errors[:name], "can't be blank"
  end

  test "invalid without principal_type" do
    policy = AccessPolicy.new(
      project: projects(:acme),
      name: "Test"
    )
    assert_not policy.valid?
    assert_includes policy.errors[:principal_type], "can't be blank"
  end

  test "principal_type must be valid" do
    policy = AccessPolicy.new(
      project: projects(:acme),
      name: "Test",
      principal_type: "invalid_type"
    )
    assert_not policy.valid?
    assert_includes policy.errors[:principal_type], "is not included in the list"
  end

  test "valid principal_types" do
    %w[user team token].each do |type|
      policy = AccessPolicy.new(
        project: projects(:acme),
        name: "Test",
        principal_type: type
      )
      assert policy.valid?, "#{type} should be valid"
    end
  end

  # ===========================================
  # Constants
  # ===========================================

  test "PERMISSIONS constant has correct values" do
    assert_equal %w[read write delete admin], AccessPolicy::PERMISSIONS
  end

  # ===========================================
  # Associations
  # ===========================================

  test "belongs to project" do
    policy = access_policies(:acme_admin_policy)
    assert_respond_to policy, :project
    assert_equal projects(:acme), policy.project
  end

  # ===========================================
  # Scopes
  # ===========================================

  test "enabled scope returns active policies" do
    enabled_policies = AccessPolicy.enabled

    assert enabled_policies.include?(access_policies(:acme_admin_policy))
    assert_not enabled_policies.include?(access_policies(:acme_inactive_policy))
  end

  test "for_principal scope filters by type and id" do
    policy = access_policies(:acme_admin_policy)
    found = AccessPolicy.for_principal(policy.principal_type, policy.principal_id)

    assert found.include?(policy)
  end

  # ===========================================
  # Instance Methods
  # ===========================================

  test "matches? returns false when disabled" do
    policy = access_policies(:acme_inactive_policy)
    secret = secrets(:acme_database_url)
    env = secret_environments(:acme_development)

    assert_not policy.matches?(secret, env, "read")
  end

  test "matches? checks environment restrictions" do
    policy = access_policies(:acme_dev_readonly)
    secret = secrets(:acme_database_url)

    dev_env = secret_environments(:acme_development)
    prod_env = secret_environments(:acme_production)

    assert policy.matches?(secret, dev_env, "read")
    assert_not policy.matches?(secret, prod_env, "read")
  end

  test "matches? checks path patterns" do
    policy = access_policies(:acme_database_restricted)
    env = secret_environments(:acme_development)

    db_secret = secrets(:acme_database_url)
    api_secret = secrets(:acme_api_key)

    # Policy allows database/* paths
    assert policy.matches?(db_secret, env, "read")
    # API key is not in database folder
    assert_not policy.matches?(api_secret, env, "read")
  end

  test "matches? checks permission" do
    policy = access_policies(:acme_dev_readonly)
    secret = secrets(:acme_database_url)
    env = secret_environments(:acme_development)

    assert policy.matches?(secret, env, "read")
    assert_not policy.matches?(secret, env, "write")
    assert_not policy.matches?(secret, env, "delete")
  end

  test "check_conditions returns true when no conditions" do
    policy = AccessPolicy.new(conditions: nil)
    assert policy.check_conditions({})

    policy.conditions = {}
    assert policy.check_conditions({})
  end

  test "check_conditions checks MFA requirement" do
    policy = access_policies(:acme_mfa_required)

    assert_not policy.check_conditions({ mfa_verified: false })
    assert_not policy.check_conditions({})
    assert policy.check_conditions({ mfa_verified: true })
  end

  test "check_conditions checks IP allowlist" do
    policy = access_policies(:acme_database_restricted)

    # Policy allows 10.0.0.0/8 and 192.168.1.0/24
    assert policy.check_conditions({ ip: "10.0.0.50" })
    assert policy.check_conditions({ ip: "192.168.1.100" })
    assert_not policy.check_conditions({ ip: "172.16.0.1" })

    # No IP provided should pass
    assert policy.check_conditions({})
  end

  test "check_conditions handles invalid IP" do
    policy = AccessPolicy.new(
      conditions: { "allowed_ips" => [ "10.0.0.0/8" ] }
    )

    # Invalid IP should return false
    assert_not policy.check_conditions({ ip: "invalid-ip" })
  end

  test "check_conditions checks time window" do
    policy = access_policies(:acme_time_window)

    # Time window is 09:00-17:00 America/New_York
    # This test is time-dependent, so we use Timecop
    Timecop.freeze(Time.zone.parse("2024-01-15 12:00:00 EST")) do
      assert policy.check_conditions({})
    end

    Timecop.freeze(Time.zone.parse("2024-01-15 20:00:00 EST")) do
      assert_not policy.check_conditions({})
    end
  end

  test "check_conditions handles missing timezone" do
    policy = AccessPolicy.new(
      conditions: { "time_window" => { "start" => "09:00", "end" => "17:00" } }
    )

    # Should default to UTC
    Timecop.freeze(Time.zone.parse("2024-01-15 12:00:00 UTC")) do
      assert policy.check_conditions({})
    end
  end
end
