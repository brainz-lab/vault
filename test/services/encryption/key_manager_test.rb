# frozen_string_literal: true

require "test_helper"

module Encryption
  class KeyManagerTest < ActiveSupport::TestCase
    setup do
      Rails.application.config.vault_master_key = "test-master-key-for-testing"
      # Use fresh project to avoid fixture key issues
      @project = create_project
    end

    # ===========================================
    # .current_key
    # ===========================================

    test "current_key returns existing active key" do
      # Create a key first
      KeyManager.create_key(@project.id)

      key = KeyManager.current_key(@project.id)

      assert key.is_a?(KeyManager::KeyWrapper)
      assert key.key_id.present?
      assert key.raw_key.present?
      assert_equal 32, key.raw_key.bytesize
    end

    test "current_key creates new key if none exists" do
      # Create fresh project without keys
      project = create_project

      key = KeyManager.current_key(project.id)

      assert key.is_a?(KeyManager::KeyWrapper)
      assert_equal project.id, key.record.project_id
      assert_equal "active", key.record.status
    end

    # Note: Global keys (without project_id) are not supported.
    # All encryption keys must belong to a project for security isolation.

    # ===========================================
    # .get_key
    # ===========================================

    test "get_key retrieves key by key_id" do
      # First create a key
      created_key = KeyManager.create_key(@project.id)

      # Then retrieve it
      key = KeyManager.get_key(created_key.key_id, project_id: @project.id)

      assert_equal created_key.key_id, key.key_id
      assert_equal created_key.raw_key, key.raw_key
    end

    test "get_key raises error for non-existent key" do
      assert_raises(ActiveRecord::RecordNotFound) do
        KeyManager.get_key("non-existent-key-id")
      end
    end

    # ===========================================
    # .create_key
    # ===========================================

    test "create_key creates new encryption key" do
      project = create_project
      initial_count = EncryptionKey.count

      key = KeyManager.create_key(project.id)

      assert_equal initial_count + 1, EncryptionKey.count
      assert key.is_a?(KeyManager::KeyWrapper)
      assert_equal project.id, key.record.project_id
      assert_equal "active", key.record.status
      assert_equal "aes-256-gcm", key.record.key_type
    end

    test "create_key stores encrypted key" do
      project = create_project
      key = KeyManager.create_key(project.id)

      assert key.record.encrypted_key.present?
      assert key.record.encryption_iv.present?
      assert_equal "local", key.record.kms_provider
    end

    # ===========================================
    # .rotate_key
    # ===========================================

    test "rotate_key creates new key and retires old" do
      project = create_project
      old_key = KeyManager.current_key(project.id)
      old_key_id = old_key.key_id

      new_key = KeyManager.rotate_key(project.id)

      assert_not_equal old_key_id, new_key.key_id
      assert_equal "active", new_key.record.status

      old_key_record = EncryptionKey.find_by(key_id: old_key_id)
      assert_equal "retired", old_key_record.status
      assert old_key_record.retired_at.present?
    end

    # ===========================================
    # KeyWrapper
    # ===========================================

    test "KeyWrapper exposes key_id from record" do
      key = KeyManager.current_key(@project.id)

      assert_equal key.record.key_id, key.key_id
    end

    test "KeyWrapper stores 32-byte raw key" do
      key = KeyManager.current_key(@project.id)

      assert_equal 32, key.raw_key.bytesize
    end
  end
end
