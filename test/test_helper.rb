# frozen_string_literal: true

# SimpleCov must be started before any application code is loaded
require "simplecov"
SimpleCov.start "rails" do
  add_filter "/test/"
  add_filter "/config/"
  add_filter "/vendor/"

  add_group "Models", "app/models"
  add_group "Controllers", "app/controllers"
  add_group "Services", "app/services"
  add_group "Helpers", "app/helpers"

  # Start with no minimum during development, raise as coverage improves
  # minimum_coverage 100
  # minimum_coverage_by_file 90
end

ENV["RAILS_ENV"] ||= "test"
ENV["BRAINZLAB_SDK_ENABLED"] = "false"  # Disable SDK during tests

require_relative "../config/environment"
require "rails/test_help"
require "webmock/minitest"
require "timecop"
require "minitest/reporters"
require "minitest/mock"

Minitest::Reporters.use! Minitest::Reporters::SpecReporter.new

# Allow localhost connections for integration tests
WebMock.disable_net_connect!(allow_localhost: true)

module ActiveSupport
  class TestCase
    # Use transactional tests to properly rollback fixtures
    self.use_transactional_tests = true

    # Disable parallel workers to avoid fixture conflicts
    parallelize(workers: 1)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...

    # Helper to create a valid project with all dependencies
    def create_project(attrs = {})
      Project.create!({
        platform_project_id: SecureRandom.uuid,
        name: "Test Project",
        environment: "live"
      }.merge(attrs))
    end

    # Helper to create a secret (no encrypted value by default)
    def create_secret(project:, key: nil, folder: nil, **attrs)
      key_name = key || "TEST_SECRET_#{SecureRandom.hex(4).upcase}"
      secret = project.secrets.create!(
        key: key_name,
        secret_folder: folder,
        description: attrs[:description] || "Test secret",
        **attrs.except(:description, :folder)
      )
      secret
    end

    # Helper to create a secret version
    def create_secret_version(secret:, environment:, value: "test_value", version: nil)
      ver = version || (secret.versions.where(secret_environment: environment).maximum(:version).to_i + 1)
      SecretVersion.create!(
        secret: secret,
        secret_environment: environment,
        version: ver,
        encrypted_value: "encrypted_#{value}",
        encryption_iv: "iv_#{SecureRandom.hex(8)}",
        encryption_key_id: "key_test_001",
        current: true,
        value_length: value.length,
        value_hash: ::Digest::SHA256.hexdigest(value)
      )
    end

    # Helper to create an access token
    def create_access_token(project:, permissions: %w[read write], environments: [], **attrs)
      token = project.access_tokens.new({
        name: "Test Token",
        permissions: permissions,
        environments: environments
      }.merge(attrs))
      token.save!
      token
    end

    # Helper to get raw token value (only available on create)
    def create_token_with_raw_value(project:, **attrs)
      token = project.access_tokens.new({
        name: "Test Token",
        permissions: %w[read write],
        environments: []
      }.merge(attrs))
      token.save!
      [ token, token.plain_token ]
    end

    # Helper to create an encryption key for testing
    def create_encryption_key(project: nil, status: "active")
      proj = project || create_project
      EncryptionKey.create!(
        project: proj,
        key_id: "key_#{SecureRandom.hex(8)}",
        key_type: "aes-256-gcm",
        encrypted_key: "encrypted_#{SecureRandom.hex(16)}",
        encryption_iv: "iv_#{SecureRandom.hex(8)}",
        status: status
      )
    end

    # Freeze time for consistent testing
    def freeze_time(&block)
      Timecop.freeze(Time.current, &block)
    end

    # Assert that a block raises a specific error
    def assert_raises_with_message(exception_class, message, &block)
      error = assert_raises(exception_class, &block)
      assert_match message, error.message
    end
  end
end

module ActionDispatch
  class IntegrationTest
    # Helper to authenticate API requests with a token
    def authenticate_with_token(token_value)
      @auth_headers = { "Authorization" => "Bearer #{token_value}" }
    end

    # Helper to authenticate API requests with API key
    def authenticate_with_api_key(api_key)
      @auth_headers = { "X-API-Key" => api_key }
    end

    # Helper for JSON API requests
    def json_headers
      { "Content-Type" => "application/json", "Accept" => "application/json" }
    end

    # Helper to get JSON response body
    def json_response
      JSON.parse(response.body)
    end

    # Combined auth + JSON headers
    def authenticated_json_headers
      json_headers.merge(@auth_headers || {})
    end
  end
end

# Stub PlatformClient for tests
class PlatformClient
  def self.validate_key(api_key)
    if api_key == "valid_key"
      {
        valid: true,
        project_id: "prj_test123",
        project_name: "Test Project",
        environment: "live",
        features: { vault: true }
      }
    elsif api_key&.start_with?("vlt_")
      nil # Will be handled by find_project_by_api_key
    else
      { valid: false }
    end
  end

  def self.track_usage(project_id:, product:, metric:, count:)
    # Stub - do nothing in tests
    true
  end

  def self.get_project_config(platform_project_id:)
    {
      name: "Test Project",
      environment: "live"
    }
  end
end
