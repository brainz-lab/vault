require "rails_helper"

RSpec.describe SshConnection, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:project) }
    it { is_expected.to belong_to(:ssh_client_key).optional }
    it { is_expected.to belong_to(:jump_connection).class_name("SshConnection").optional }
    it { is_expected.to have_many(:dependent_connections) }
  end

  describe "validations" do
    subject { build(:ssh_connection) }

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:host) }
    it { is_expected.to validate_presence_of(:username) }
    it { is_expected.to validate_presence_of(:port) }

    describe "port numericality" do
      it "accepts port 22" do
        conn = build(:ssh_connection, port: 22)
        expect(conn).to be_valid
      end

      it "rejects port 0" do
        conn = build(:ssh_connection, port: 0)
        conn.valid?
        expect(conn.errors[:port]).to be_present
      end

      it "rejects port 65536" do
        conn = build(:ssh_connection, port: 65536)
        conn.valid?
        expect(conn.errors[:port]).to be_present
      end

      it "rejects non-integer port" do
        conn = build(:ssh_connection, port: 22.5)
        conn.valid?
        expect(conn.errors[:port]).to be_present
      end
    end
  end

  describe "scopes" do
    let(:project) { create(:project) }

    describe ".active" do
      let!(:active_conn)   { create(:ssh_connection, project: project, archived: false) }
      let!(:archived_conn) { create(:ssh_connection, project: project, archived: true) }

      it "returns only non-archived connections" do
        expect(SshConnection.active).to include(active_conn)
        expect(SshConnection.active).not_to include(archived_conn)
      end
    end

    describe ".with_jump" do
      let(:jump_conn)       { create(:ssh_connection, project: project) }
      let!(:proxied_conn)   { create(:ssh_connection, project: project, jump_connection: jump_conn) }
      let!(:direct_conn)    { create(:ssh_connection, project: project, jump_connection: nil) }

      it "returns only connections with a jump host" do
        expect(SshConnection.with_jump).to include(proxied_conn)
        expect(SshConnection.with_jump).not_to include(direct_conn)
      end
    end
  end

  describe "#archive!" do
    let(:conn) { create(:ssh_connection, archived: false) }

    it "sets archived to true" do
      conn.archive!
      expect(conn.reload.archived).to be true
    end
  end

  describe "#restore!" do
    let(:conn) { create(:ssh_connection, archived: true) }

    it "sets archived to false" do
      conn.restore!
      expect(conn.reload.archived).to be false
    end
  end

  describe "#to_ssh_config" do
    let(:project) { create(:project) }
    let(:conn) do
      create(:ssh_connection,
        project: project,
        name: "prod-server",
        host: "prod.example.com",
        username: "deploy",
        port: 22
      )
    end

    it "returns a string" do
      expect(conn.to_ssh_config).to be_a(String)
    end

    it "includes Host directive" do
      expect(conn.to_ssh_config).to include("Host")
    end

    it "includes HostName" do
      expect(conn.to_ssh_config).to include("prod.example.com")
    end

    it "includes User" do
      expect(conn.to_ssh_config).to include("deploy")
    end

    it "includes Port" do
      expect(conn.to_ssh_config).to include("22")
    end

    context "with a jump host" do
      let(:jump_conn) { create(:ssh_connection, project: project, host: "bastion.example.com") }
      let(:proxied_conn) do
        create(:ssh_connection, project: project, host: "internal.example.com",
               username: "app", port: 22, jump_connection: jump_conn)
      end

      it "includes ProxyJump directive" do
        expect(proxied_conn.to_ssh_config).to include("ProxyJump")
      end
    end
  end

  describe "#to_summary" do
    let(:conn) { create(:ssh_connection) }

    it "returns a hash" do
      expect(conn.to_summary).to be_a(Hash)
    end

    it "includes connection name" do
      summary = conn.to_summary
      expect(summary.to_s).to include(conn.name)
    end

    it "does not include private key data" do
      summary = conn.to_summary
      expect(summary.to_s).not_to include("encrypted_private_key")
    end
  end
end
