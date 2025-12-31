# frozen_string_literal: true

require "test_helper"

class RotateSecretJobTest < ActiveSupport::TestCase
  setup do
    @project = projects(:acme)
    @secret = secrets(:acme_api_key)
    @environment = secret_environments(:acme_development)
    Rails.application.config.vault_master_key = "test-master-key-for-testing"
  end

  test "queues on default priority" do
    assert_equal "default", RotateSecretJob.new.queue_name
  end

  test "generates random value for api_key type" do
    job = RotateSecretJob.new
    @secret.update!(tags: { "type" => "api_key" })

    value = job.send(:generate_random_value, @secret)
    assert_equal 64, value.length  # hex(32) = 64 chars
  end

  test "generates random value for password type" do
    job = RotateSecretJob.new
    @secret.update!(tags: { "type" => "password" })

    value = job.send(:generate_random_value, @secret)
    assert_equal 32, value.length
  end

  test "generates random value for jwt_secret type" do
    job = RotateSecretJob.new
    @secret.update!(tags: { "type" => "jwt_secret" })

    value = job.send(:generate_random_value, @secret)
    assert value.length > 0  # Base64 encoded
  end

  test "generates random value for default type" do
    job = RotateSecretJob.new
    @secret.update!(tags: {})

    value = job.send(:generate_random_value, @secret)
    assert_equal 64, value.length  # hex(32) = 64 chars
  end
end
