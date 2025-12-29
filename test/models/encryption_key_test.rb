# frozen_string_literal: true

require "test_helper"

class EncryptionKeyTest < ActiveSupport::TestCase
  # ===========================================
  # Validations
  # ===========================================

  test "valid encryption key with all required attributes" do
    key = EncryptionKey.new(
      project: projects(:acme),
      key_id: "key_new_#{SecureRandom.hex(8)}",
      key_type: "aes-256-gcm",
      encrypted_key: "encrypted_data",
      encryption_iv: "random_iv"
    )
    assert key.valid?
  end

  test "invalid without key_id" do
    key = EncryptionKey.new(
      project: projects(:acme),
      key_type: "aes-256-gcm",
      encrypted_key: "data",
      encryption_iv: "iv"
    )
    assert_not key.valid?
    assert_includes key.errors[:key_id], "can't be blank"
  end

  test "key_id must be unique per project" do
    existing = encryption_keys(:acme_active_key)
    duplicate = EncryptionKey.new(
      project: existing.project,
      key_id: existing.key_id,
      key_type: "aes-256-gcm",
      encrypted_key: "data",
      encryption_iv: "iv"
    )
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:key_id], "has already been taken"
  end

  test "key_id can be duplicated across projects" do
    key1 = encryption_keys(:acme_active_key)
    key2 = EncryptionKey.new(
      project: projects(:startup),
      key_id: key1.key_id,
      key_type: "aes-256-gcm",
      encrypted_key: "data",
      encryption_iv: "iv"
    )
    assert key2.valid?
  end

  test "invalid without key_type" do
    key = EncryptionKey.new(
      project: projects(:acme),
      key_id: "key_123",
      encrypted_key: "data",
      encryption_iv: "iv"
    )
    assert_not key.valid?
    assert_includes key.errors[:key_type], "can't be blank"
  end

  test "invalid without encrypted_key" do
    key = EncryptionKey.new(
      project: projects(:acme),
      key_id: "key_123",
      key_type: "aes-256-gcm",
      encryption_iv: "iv"
    )
    assert_not key.valid?
    assert_includes key.errors[:encrypted_key], "can't be blank"
  end

  test "invalid without encryption_iv" do
    key = EncryptionKey.new(
      project: projects(:acme),
      key_id: "key_123",
      key_type: "aes-256-gcm",
      encrypted_key: "data"
    )
    assert_not key.valid?
    assert_includes key.errors[:encryption_iv], "can't be blank"
  end

  # ===========================================
  # Constants
  # ===========================================

  test "STATUSES constant has correct values" do
    assert_equal %w[active rotating retired], EncryptionKey::STATUSES
  end

  # ===========================================
  # Associations
  # ===========================================

  test "belongs to project" do
    key = encryption_keys(:acme_active_key)
    assert_respond_to key, :project
    assert_equal projects(:acme), key.project
  end

  test "belongs to previous_key optionally" do
    key = encryption_keys(:acme_active_key)
    assert_respond_to key, :previous_key
  end

  test "has many successor_keys" do
    key = encryption_keys(:acme_active_key)
    assert_respond_to key, :successor_keys
  end

  # ===========================================
  # Scopes
  # ===========================================

  test "active scope returns only active keys" do
    active_keys = EncryptionKey.active

    active_keys.each do |key|
      assert_equal "active", key.status
    end
  end

  test "for_project scope filters by project" do
    project = projects(:acme)
    keys = EncryptionKey.for_project(project)

    keys.each do |key|
      assert_equal project, key.project
    end
  end

  # ===========================================
  # Instance Methods
  # ===========================================

  test "active? returns true when status is active" do
    key = EncryptionKey.new(status: "active")
    assert key.active?

    key.status = "retired"
    assert_not key.active?
  end

  test "retired? returns true when status is retired" do
    key = EncryptionKey.new(status: "retired")
    assert key.retired?

    key.status = "active"
    assert_not key.retired?
  end

  test "rotating? returns true when status is rotating" do
    key = EncryptionKey.new(status: "rotating")
    assert key.rotating?

    key.status = "active"
    assert_not key.rotating?
  end

  test "retire! sets status to retired" do
    key = create_encryption_key

    assert_not key.retired?

    key.retire!
    key.reload

    assert key.retired?
    assert_equal "retired", key.status
    assert_not_nil key.retired_at
  end

  test "activate! sets status to active" do
    key = create_encryption_key(status: "rotating")

    assert_not key.active?

    key.activate!
    key.reload

    assert key.active?
    assert_equal "active", key.status
    assert_not_nil key.activated_at
  end
end
