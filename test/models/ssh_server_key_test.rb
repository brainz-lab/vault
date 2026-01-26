require "test_helper"

class SshServerKeyTest < ActiveSupport::TestCase
  setup do
    @project = projects(:acme)
  end

  test "validates presence of required fields" do
    key = SshServerKey.new
    assert_not key.valid?
    assert_includes key.errors[:hostname], "can't be blank"
    assert_includes key.errors[:key_type], "can't be blank"
    assert_includes key.errors[:public_key], "can't be blank"
    assert_includes key.errors[:fingerprint], "can't be blank"
  end

  test "validates port range" do
    key = SshServerKey.new(port: 0)
    assert_not key.valid?
    assert_includes key.errors[:port], "must be greater than 0"

    key.port = 65536
    assert_not key.valid?
    assert_includes key.errors[:port], "must be less than 65536"
  end

  test "default port is 22" do
    key = SshServerKey.new(project: @project)
    assert_equal 22, key.port
  end

  test "active scope excludes archived keys" do
    assert @project.ssh_server_keys.active.none?(&:archived?)
  end

  test "trusted scope returns only trusted keys" do
    trusted = @project.ssh_server_keys.trusted
    assert trusted.all?(&:trusted?)
  end

  test "by_host scope filters by hostname and port" do
    keys = @project.ssh_server_keys.by_host("github.com", 22)
    assert keys.all? { |k| k.hostname == "github.com" && k.port == 22 }
  end

  test "to_known_hosts_line formats correctly" do
    key = ssh_server_keys(:github_key)
    line = key.to_known_hosts_line

    assert_includes line, "[github.com]:22"
    assert_includes line, "ssh-ed25519"
    assert_includes line, key.public_key
  end

  test "mark_verified! updates verified_at" do
    key = ssh_server_keys(:untrusted_key)
    assert_nil key.verified_at

    key.mark_verified!

    assert_not_nil key.verified_at
  end

  test "trust! and untrust! toggle trusted flag" do
    key = ssh_server_keys(:untrusted_key)
    assert_not key.trusted?

    key.trust!
    assert key.trusted?

    key.untrust!
    assert_not key.trusted?
  end
end
