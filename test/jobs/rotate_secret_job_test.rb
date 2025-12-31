# frozen_string_literal: true

require "test_helper"

class RotateSecretJobTest < ActiveSupport::TestCase
  setup do
    @project = projects(:acme)
    @secret = secrets(:acme_api_key)  # Use secret with only one version
    @environment = secret_environments(:acme_development)
    # Fixtures already have version 1 for this secret
  end

  test "performs with new value" do
    assert_difference "@secret.versions.count", 1 do
      RotateSecretJob.perform_now(
        secret_id: @secret.id,
        environment_id: @environment.id,
        new_value: "rotated_value"
      )
    end
  end

  test "performs with generated value" do
    assert_difference "@secret.versions.count", 1 do
      RotateSecretJob.perform_now(
        secret_id: @secret.id,
        environment_id: @environment.id
      )
    end
  end

  test "creates audit log" do
    assert_difference "AuditLog.count", 1 do
      RotateSecretJob.perform_now(
        secret_id: @secret.id,
        environment_id: @environment.id,
        new_value: "new_value"
      )
    end
  end

  test "generates api_key type value" do
    @secret.update!(tags: { "type" => "api_key" })

    RotateSecretJob.perform_now(
      secret_id: @secret.id,
      environment_id: @environment.id
    )

    # Should complete without error
  end

  test "generates password type value" do
    @secret.update!(tags: { "type" => "password" })

    RotateSecretJob.perform_now(
      secret_id: @secret.id,
      environment_id: @environment.id
    )

    # Should complete without error
  end

  test "queues on default priority" do
    assert_equal "default", RotateSecretJob.new.queue_name
  end
end
