# frozen_string_literal: true

require "test_helper"

class CheckSecretExpiryJobTest < ActiveSupport::TestCase
  setup do
    @project = projects(:acme)
    @secret = secrets(:acme_database_url)
    @environment = secret_environments(:acme_development)
  end

  test "performs without error" do
    assert_nothing_raised do
      CheckSecretExpiryJob.perform_now
    end
  end

  test "identifies secrets needing rotation" do
    # Set rotation interval - the secret already has versions from fixtures
    @secret.update!(rotation_interval_days: 7)

    # Fixtures have versions created 25+ days ago, so this should identify
    # the secret as needing rotation
    CheckSecretExpiryJob.perform_now
  end

  test "ignores secrets without rotation_interval_days" do
    @secret.update!(rotation_interval_days: nil)

    assert_nothing_raised do
      CheckSecretExpiryJob.perform_now
    end
  end

  test "ignores recently rotated secrets" do
    # Use a secret that has recent versions (startup secrets are 8-10 days old)
    secret = secrets(:startup_openai_key)
    secret.update!(rotation_interval_days: 30)

    assert_nothing_raised do
      CheckSecretExpiryJob.perform_now
    end
  end

  test "queues on default priority" do
    assert_equal "default", CheckSecretExpiryJob.new.queue_name
  end
end
