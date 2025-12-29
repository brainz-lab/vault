# frozen_string_literal: true

require "test_helper"

class AccessTokenTest < ActiveSupport::TestCase
  # ===========================================
  # Validations
  # ===========================================

  test "valid access token with all required attributes" do
    token = AccessToken.new(
      project: projects(:acme),
      name: "Test Token"
    )
    assert token.valid?
  end

  test "invalid without name" do
    token = AccessToken.new(project: projects(:acme))
    assert_not token.valid?
    assert_includes token.errors[:name], "can't be blank"
  end

  test "token_digest generated on create" do
    token = AccessToken.new(
      project: projects(:acme),
      name: "New Token"
    )
    token.valid?

    assert_not_nil token.token_digest
    assert token.token_digest.length == 64 # SHA256 hex
  end

  test "token_digest must be unique per project" do
    existing = access_tokens(:acme_admin_token)
    duplicate = AccessToken.new(
      project: existing.project,
      name: "Duplicate",
      token_digest: existing.token_digest
    )
    # Skip callback to test validation
    duplicate.instance_variable_set(:@skip_generate, true)
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:token_digest], "has already been taken"
  end

  # ===========================================
  # Callbacks
  # ===========================================

  test "generates token on create" do
    token = AccessToken.create!(
      project: projects(:acme),
      name: "Generated Token"
    )

    assert_not_nil token.plain_token
    assert_not_nil token.token_prefix
    assert_not_nil token.token_digest

    assert_equal token.plain_token[0..7], token.token_prefix
    assert_equal Digest::SHA256.hexdigest(token.plain_token), token.token_digest
  end

  test "plain_token only available on create" do
    token = AccessToken.create!(
      project: projects(:acme),
      name: "Temp Token"
    )
    plain = token.plain_token
    assert_not_nil plain, "plain_token should be available immediately after create"

    # Fetch a fresh instance from the database - it shouldn't have plain_token
    fresh_token = AccessToken.find(token.id)
    assert_nil fresh_token.plain_token, "plain_token should not be available on a fresh load"
  end

  # ===========================================
  # Scopes
  # ===========================================

  test "active scope returns non-revoked non-expired tokens" do
    active_tokens = AccessToken.active

    assert active_tokens.include?(access_tokens(:acme_admin_token))
    assert_not active_tokens.include?(access_tokens(:acme_revoked_token))
    assert_not active_tokens.include?(access_tokens(:acme_expired_token))
  end

  # ===========================================
  # Associations
  # ===========================================

  test "belongs to project" do
    token = access_tokens(:acme_admin_token)
    assert_respond_to token, :project
    assert_equal projects(:acme), token.project
  end

  # ===========================================
  # Class Methods
  # ===========================================

  test "authenticate finds token by prefix and digest" do
    # Create a new token to test with
    token = AccessToken.create!(
      project: projects(:acme),
      name: "Auth Test Token"
    )
    plain_token = token.plain_token

    found = AccessToken.authenticate(plain_token)

    assert_equal token.id, found.id
  end

  test "authenticate returns nil for unknown token" do
    assert_nil AccessToken.authenticate("unknown_token_value")
  end

  test "authenticate returns nil for nil token" do
    assert_nil AccessToken.authenticate(nil)
  end

  test "authenticate returns nil for blank token" do
    assert_nil AccessToken.authenticate("")
  end

  test "authenticate updates last_used_at and use_count" do
    token = AccessToken.create!(
      project: projects(:acme),
      name: "Usage Test Token"
    )
    plain_token = token.plain_token
    initial_count = token.use_count

    AccessToken.authenticate(plain_token)
    token.reload

    assert_not_nil token.last_used_at
    assert_equal initial_count + 1, token.use_count
  end

  # ===========================================
  # Instance Methods
  # ===========================================

  test "can_access? returns false when not active" do
    token = access_tokens(:acme_revoked_token)
    secret = secrets(:acme_database_url)
    env = secret_environments(:acme_development)

    assert_not token.can_access?(secret, env)
  end

  test "can_access? checks environment restrictions" do
    token = access_tokens(:acme_readonly_token)
    secret = secrets(:acme_database_url)

    dev_env = secret_environments(:acme_development)
    prod_env = secret_environments(:acme_production)

    # Token allows development and staging
    assert token.can_access?(secret, dev_env)
    assert_not token.can_access?(secret, prod_env)
  end

  test "can_access? checks permission" do
    token = access_tokens(:acme_readonly_token)
    secret = secrets(:acme_database_url)
    env = secret_environments(:acme_development)

    assert token.can_access?(secret, env, permission: "read")
    assert_not token.can_access?(secret, env, permission: "write")
  end

  test "revoke! sets revoked state" do
    token = AccessToken.create!(
      project: projects(:acme),
      name: "To Revoke"
    )

    assert_not token.revoked?

    token.revoke!(by: "admin_user")
    token.reload

    assert token.revoked?
    assert_not token.active?
    assert_not_nil token.revoked_at
    assert_equal "admin_user", token.revoked_by
  end

  test "regenerate! creates new token" do
    token = AccessToken.create!(
      project: projects(:acme),
      name: "To Regenerate"
    )
    old_digest = token.token_digest
    old_prefix = token.token_prefix

    new_plain = token.regenerate!

    assert_not_nil new_plain
    assert_not_equal old_digest, token.token_digest
    assert_not_equal old_prefix, token.token_prefix
    assert_equal 0, token.use_count
    assert_nil token.last_used_at
  end

  test "expired? returns true when expires_at is in the past" do
    token = AccessToken.new(expires_at: 1.day.ago)
    assert token.expired?

    token.expires_at = 1.day.from_now
    assert_not token.expired?

    token.expires_at = nil
    assert_not token.expired?
  end

  test "revoked? returns true when revoked_at is set" do
    token = AccessToken.new
    assert_not token.revoked?

    token.revoked_at = Time.current
    assert token.revoked?
  end

  test "authenticate instance method verifies raw token" do
    token = AccessToken.create!(
      project: projects(:acme),
      name: "Instance Auth Test"
    )
    plain_token = token.plain_token

    assert token.authenticate(plain_token)
    assert_not token.authenticate("wrong_token")
    assert_not token.authenticate(nil)
    assert_not token.authenticate("")
  end

  test "has_permission? checks permission array" do
    token = access_tokens(:acme_admin_token)

    assert token.has_permission?("read")
    assert token.has_permission?("write")
    assert token.has_permission?("admin")
    assert token.has_permission?(:read) # Symbol works too

    readonly_token = access_tokens(:acme_readonly_token)
    assert readonly_token.has_permission?("read")
    assert_not readonly_token.has_permission?("write")
  end
end
