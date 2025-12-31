# frozen_string_literal: true

require "test_helper"

class ExpireTokensJobTest < ActiveSupport::TestCase
  setup do
    @project = projects(:acme)
  end

  test "performs without error" do
    assert_nothing_raised do
      ExpireTokensJob.perform_now
    end
  end

  test "revokes expired tokens" do
    # Create an expired token
    token = @project.access_tokens.create!(
      name: "Expired Token",
      permissions: %w[read],
      expires_at: 1.day.ago
    )

    ExpireTokensJob.perform_now

    token.reload
    assert token.revoked?
  end

  test "does not revoke active tokens" do
    # Create a valid token
    token = @project.access_tokens.create!(
      name: "Valid Token",
      permissions: %w[read],
      expires_at: 1.day.from_now
    )

    ExpireTokensJob.perform_now

    token.reload
    refute token.revoked?
  end

  test "does not revoke tokens without expiry" do
    token = @project.access_tokens.create!(
      name: "No Expiry Token",
      permissions: %w[read],
      expires_at: nil
    )

    ExpireTokensJob.perform_now

    token.reload
    refute token.revoked?
  end

  test "creates audit log for expired tokens" do
    # Clean up any existing expired tokens first
    AccessToken.where("expires_at < ?", Time.current).update_all(revoked_at: Time.current)

    token = @project.access_tokens.create!(
      name: "Expired Token",
      permissions: %w[read],
      expires_at: 1.day.ago
    )

    assert_difference "AuditLog.count", 1 do
      ExpireTokensJob.perform_now
    end
  end

  test "queues on low priority" do
    assert_equal "low", ExpireTokensJob.new.queue_name
  end
end
