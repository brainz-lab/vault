require "test_helper"

class SshConnectionTest < ActiveSupport::TestCase
  setup do
    @project = projects(:acme)
  end

  test "validates presence of required fields" do
    conn = SshConnection.new
    assert_not conn.valid?
    assert_includes conn.errors[:name], "can't be blank"
    assert_includes conn.errors[:host], "can't be blank"
    assert_includes conn.errors[:username], "can't be blank"
  end

  test "validates port range" do
    conn = SshConnection.new(port: 0)
    assert_not conn.valid?
    assert_includes conn.errors[:port], "must be greater than 0"

    conn.port = 65536
    assert_not conn.valid?
    assert_includes conn.errors[:port], "must be less than 65536"
  end

  test "default port is 22" do
    conn = SshConnection.new(project: @project)
    assert_equal 22, conn.port
  end

  test "active scope excludes archived connections" do
    assert @project.ssh_connections.active.none?(&:archived?)
  end

  test "with_jump scope returns connections with jump host" do
    jump_conns = @project.ssh_connections.with_jump
    assert jump_conns.all? { |c| c.jump_connection_id.present? }
  end

  test "belongs to optional ssh_client_key" do
    conn = ssh_connections(:production_server)
    assert_not_nil conn.ssh_client_key
    assert_equal "deploy-key", conn.ssh_client_key.name
  end

  test "belongs to optional jump_connection" do
    conn = ssh_connections(:internal_server)
    assert_not_nil conn.jump_connection
    assert_equal "bastion", conn.jump_connection.name
  end

  test "has_many dependent_connections" do
    bastion = ssh_connections(:bastion_server)
    assert bastion.dependent_connections.any?
    assert_includes bastion.dependent_connections, ssh_connections(:internal_server)
  end

  test "to_summary returns expected fields" do
    conn = ssh_connections(:production_server)
    summary = conn.to_summary

    assert_equal conn.id, summary[:id]
    assert_equal conn.name, summary[:name]
    assert_equal conn.host, summary[:host]
    assert_equal conn.port, summary[:port]
    assert_equal conn.username, summary[:username]
    assert_equal "deploy-key", summary[:client_key_name]
  end

  test "to_ssh_config generates valid config" do
    conn = ssh_connections(:production_server)
    config = conn.to_ssh_config

    assert_includes config, "Host prod-server"
    assert_includes config, "HostName prod.example.com"
    assert_includes config, "Port 22"
    assert_includes config, "User deploy"
    assert_includes config, "IdentityFile ~/.ssh/deploy-key"
    assert_includes config, "ServerAliveInterval 60"
  end

  test "to_ssh_config includes ProxyJump for jump connections" do
    conn = ssh_connections(:internal_server)
    config = conn.to_ssh_config

    assert_includes config, "ProxyJump bastion"
  end
end
