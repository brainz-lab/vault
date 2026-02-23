require "rails_helper"

RSpec.describe SshServerKey, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:project) }
  end

  describe "validations" do
    subject { build(:ssh_server_key) }

    it { is_expected.to validate_presence_of(:hostname) }
    it { is_expected.to validate_presence_of(:key_type) }
    it { is_expected.to validate_presence_of(:public_key) }
    it { is_expected.to validate_presence_of(:fingerprint) }
    it { is_expected.to validate_presence_of(:port) }

    describe "port numericality" do
      it "accepts a valid port number" do
        key = build(:ssh_server_key, port: 22)
        expect(key).to be_valid
      end

      it "rejects port 0" do
        key = build(:ssh_server_key, port: 0)
        key.valid?
        expect(key.errors[:port]).to be_present
      end

      it "rejects port 65536 or above" do
        key = build(:ssh_server_key, port: 65536)
        key.valid?
        expect(key.errors[:port]).to be_present
      end

      it "rejects non-integer port" do
        key = build(:ssh_server_key, port: 22.5)
        key.valid?
        expect(key.errors[:port]).to be_present
      end
    end
  end

  describe "scopes" do
    let(:project) { create(:project) }

    describe ".active" do
      let!(:active_key)   { create(:ssh_server_key, project: project, archived: false) }
      let!(:archived_key) { create(:ssh_server_key, project: project, archived: true) }

      it "returns only non-archived server keys" do
        expect(SshServerKey.active).to include(active_key)
        expect(SshServerKey.active).not_to include(archived_key)
      end
    end

    describe ".trusted" do
      let!(:trusted_key)   { create(:ssh_server_key, project: project, trusted: true) }
      let!(:untrusted_key) { create(:ssh_server_key, project: project, trusted: false) }

      it "returns only trusted server keys" do
        expect(SshServerKey.trusted).to include(trusted_key)
        expect(SshServerKey.trusted).not_to include(untrusted_key)
      end
    end

    describe ".by_host" do
      let!(:host_a) { create(:ssh_server_key, project: project, hostname: "server-a.example.com") }
      let!(:host_b) { create(:ssh_server_key, project: project, hostname: "server-b.example.com") }

      it "returns keys matching the given hostname" do
        expect(SshServerKey.by_host("server-a.example.com")).to include(host_a)
        expect(SshServerKey.by_host("server-a.example.com")).not_to include(host_b)
      end
    end

    describe ".by_fingerprint" do
      let!(:key_a) { create(:ssh_server_key, project: project, fingerprint: "SHA256:aaa") }
      let!(:key_b) { create(:ssh_server_key, project: project, fingerprint: "SHA256:bbb") }

      it "returns keys matching the given fingerprint" do
        expect(SshServerKey.by_fingerprint("SHA256:aaa")).to include(key_a)
        expect(SshServerKey.by_fingerprint("SHA256:aaa")).not_to include(key_b)
      end
    end
  end

  describe "#archive!" do
    let(:key) { create(:ssh_server_key, archived: false) }

    it "sets archived to true" do
      key.archive!
      expect(key.reload.archived).to be true
    end
  end

  describe "#restore!" do
    let(:key) { create(:ssh_server_key, archived: true) }

    it "sets archived to false" do
      key.restore!
      expect(key.reload.archived).to be false
    end
  end

  describe "#mark_verified!" do
    let(:key) { create(:ssh_server_key, verified_at: nil) }

    it "sets verified_at to current time" do
      key.mark_verified!
      expect(key.reload.verified_at).to be_present
    end
  end

  describe "#trust!" do
    let(:key) { create(:ssh_server_key, trusted: false) }

    it "sets trusted to true" do
      key.trust!
      expect(key.reload.trusted).to be true
    end
  end

  describe "#untrust!" do
    let(:key) { create(:ssh_server_key, trusted: true) }

    it "sets trusted to false" do
      key.untrust!
      expect(key.reload.trusted).to be false
    end
  end

  describe "#to_known_hosts_line" do
    let(:key) do
      build(:ssh_server_key,
        hostname: "server.example.com",
        port: 22,
        key_type: "ssh-ed25519",
        public_key: "AAAAC3NzaC1lZDI1NTE5AAAAItest"
      )
    end

    it "returns a known_hosts formatted line" do
      line = key.to_known_hosts_line
      expect(line).to include("server.example.com")
      expect(line).to include("ssh-ed25519")
      expect(line).to include("AAAAC3NzaC1lZDI1NTE5AAAAItest")
    end

    it "includes port notation in brackets" do
      line = key.to_known_hosts_line
      expect(line).to include("[server.example.com]:22")
    end
  end
end
