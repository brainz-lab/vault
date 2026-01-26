require "test_helper"

class SshClientKeyTest < ActiveSupport::TestCase
  setup do
    @project = projects(:acme)
  end

  test "validates presence of required fields" do
    key = SshClientKey.new
    assert_not key.valid?
    assert_includes key.errors[:name], "can't be blank"
    assert_includes key.errors[:key_type], "can't be blank"
    assert_includes key.errors[:fingerprint], "can't be blank"
    assert_includes key.errors[:public_key], "can't be blank"
  end

  test "validates key_type inclusion" do
    key = SshClientKey.new(key_type: "invalid")
    assert_not key.valid?
    assert_includes key.errors[:key_type], "is not included in the list"

    %w[rsa-2048 rsa-4096 ed25519].each do |valid_type|
      key.key_type = valid_type
      key.valid?
      assert_not_includes key.errors[:key_type], "is not included in the list"
    end
  end

  test "active scope excludes archived keys" do
    active_count = @project.ssh_client_keys.active.count
    total_count = @project.ssh_client_keys.count

    assert active_count < total_count
    assert @project.ssh_client_keys.active.none?(&:archived?)
  end

  test "by_type scope filters by key type" do
    ed25519_keys = @project.ssh_client_keys.by_type("ed25519")
    assert ed25519_keys.all? { |k| k.key_type == "ed25519" }
  end

  test "archive! sets archived flag and timestamp" do
    key = ssh_client_keys(:deploy_key)
    assert_not key.archived?
    assert_nil key.archived_at

    key.archive!

    assert key.archived?
    assert_not_nil key.archived_at
  end

  test "has_passphrase? returns correct value" do
    deploy_key = ssh_client_keys(:deploy_key)
    backup_key = ssh_client_keys(:backup_key)

    assert_not deploy_key.has_passphrase?
    assert backup_key.has_passphrase?
  end

  test "to_summary returns expected fields" do
    key = ssh_client_keys(:deploy_key)
    summary = key.to_summary

    assert_equal key.id, summary[:id]
    assert_equal key.name, summary[:name]
    assert_equal key.key_type, summary[:key_type]
    assert_equal key.fingerprint, summary[:fingerprint]
    assert_equal key.public_key, summary[:public_key]
    assert_not summary[:has_passphrase]
  end
end
