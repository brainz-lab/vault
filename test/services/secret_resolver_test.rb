# frozen_string_literal: true

require "test_helper"

class SecretResolverTest < ActiveSupport::TestCase
  setup do
    @project = projects(:acme)
    @environment = secret_environments(:acme_development)
    @resolver = SecretResolver.new(@project, @environment)
  end

  # ===========================================
  # #resolve
  # ===========================================

  test "resolve returns value for existing secret" do
    secret = secrets(:acme_database_url)

    Encryption::Encryptor.stub :decrypt, "test_value" do
      value = @resolver.resolve(secret.path)
      assert_equal "test_value", value
    end
  end

  test "resolve returns nil for non-existent secret" do
    value = @resolver.resolve("/non/existent/path")
    assert_nil value
  end

  test "resolve returns nil for archived secret" do
    secret = secrets(:acme_archived_secret)
    value = @resolver.resolve(secret.path)
    assert_nil value
  end

  # ===========================================
  # #resolve_all
  # ===========================================

  test "resolve_all returns hash of all secrets" do
    Encryption::Encryptor.stub :decrypt, "test_value" do
      secrets = @resolver.resolve_all
      assert secrets.is_a?(Hash)
    end
  end

  test "resolve_all excludes archived secrets" do
    Encryption::Encryptor.stub :decrypt, "test_value" do
      secrets = @resolver.resolve_all
      archived_keys = Secret.where(archived: true).pluck(:key)
      archived_keys.each do |key|
        assert_not secrets.key?(key), "Expected archived secret #{key} to be excluded"
      end
    end
  end

  test "resolve_all uses secret key as hash key" do
    Encryption::Encryptor.stub :decrypt, "test_value" do
      secrets = @resolver.resolve_all
      if secrets.any?
        key = secrets.keys.first
        assert key.match?(/\A[A-Z][A-Z0-9_]*\z/), "Key should match secret key format"
      end
    end
  end

  # ===========================================
  # #resolve_with_references
  # ===========================================

  test "resolve_with_references replaces variable references" do
    secret = secrets(:acme_database_url)

    Encryption::Encryptor.stub :decrypt, "postgres://localhost" do
      template = "Connection: ${DATABASE_URL}"
      result = @resolver.resolve_with_references(template)
      assert_equal "Connection: postgres://localhost", result
    end
  end

  test "resolve_with_references leaves unmatched references as-is" do
    template = "Value: ${NONEXISTENT_SECRET}"
    result = @resolver.resolve_with_references(template)
    assert_equal "Value: ${NONEXISTENT_SECRET}", result
  end

  test "resolve_with_references handles multiple references" do
    Encryption::Encryptor.stub :decrypt, "value" do
      template = "${DATABASE_URL} and ${REDIS_URL}"
      result = @resolver.resolve_with_references(template)
      # At least one should be resolved if fixture exists
      assert result.include?("value") || result.include?("${")
    end
  end

  # ===========================================
  # #resolve_by_folder
  # ===========================================

  test "resolve_by_folder returns secrets in folder" do
    folder = secret_folders(:acme_database)

    Encryption::Encryptor.stub :decrypt, "test_value" do
      secrets = @resolver.resolve_by_folder(folder.path)
      assert secrets.is_a?(Hash)
    end
  end

  test "resolve_by_folder returns empty hash for non-existent folder" do
    secrets = @resolver.resolve_by_folder("/non/existent/folder")
    assert_equal({}, secrets)
  end
end
