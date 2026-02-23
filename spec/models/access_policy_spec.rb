require "rails_helper"

RSpec.describe AccessPolicy, type: :model do
  describe "constants" do
    it "defines PERMISSIONS" do
      expect(AccessPolicy::PERMISSIONS).to eq(%w[read write delete admin])
    end
  end

  describe "associations" do
    it { is_expected.to belong_to(:project) }
  end

  describe "validations" do
    subject { build(:access_policy) }

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:principal_type) }
    it { is_expected.to validate_inclusion_of(:principal_type).in_array(%w[user team token]) }

    it "rejects an unknown principal_type" do
      policy = build(:access_policy, principal_type: "robot")
      policy.valid?
      expect(policy.errors[:principal_type]).to be_present
    end
  end

  describe "scopes" do
    let(:project) { create(:project) }

    describe ".enabled" do
      let!(:enabled_policy)  { create(:access_policy, project: project, enabled: true) }
      let!(:disabled_policy) { create(:access_policy, project: project, enabled: false) }

      it "returns only enabled policies" do
        expect(AccessPolicy.enabled).to include(enabled_policy)
        expect(AccessPolicy.enabled).not_to include(disabled_policy)
      end
    end

    describe ".for_principal" do
      let!(:user_policy)  { create(:access_policy, project: project, principal_type: "user",  principal_id: "user-1") }
      let!(:team_policy)  { create(:access_policy, project: project, principal_type: "team",  principal_id: "team-1") }

      it "returns policies matching the given principal type and id" do
        expect(AccessPolicy.for_principal("user", "user-1")).to include(user_policy)
        expect(AccessPolicy.for_principal("user", "user-1")).not_to include(team_policy)
      end
    end
  end

  describe "#matches?" do
    let(:project)     { create(:project) }
    let(:environment) { project.secret_environments.find_by(name: "Development") }
    let(:secret)      { create(:secret, project: project) }

    context "when policy is enabled and environment/path/permission match" do
      let(:policy) do
        create(:access_policy,
          project: project,
          enabled: true,
          environments: [environment.slug],
          paths: ["*"],
          permissions: ["read"]
        )
      end

      it "returns true" do
        expect(policy.matches?(secret, environment, "read")).to be true
      end
    end

    context "when policy is disabled" do
      let(:policy) do
        create(:access_policy,
          project: project,
          enabled: false,
          environments: [environment.slug],
          paths: ["*"],
          permissions: ["read"]
        )
      end

      it "returns false" do
        expect(policy.matches?(secret, environment, "read")).to be false
      end
    end

    context "when permission is not included" do
      let(:policy) do
        create(:access_policy,
          project: project,
          enabled: true,
          environments: [environment.slug],
          paths: ["*"],
          permissions: ["read"]
        )
      end

      it "returns false for a different permission" do
        expect(policy.matches?(secret, environment, "delete")).to be false
      end
    end
  end

  describe "#check_conditions" do
    let(:policy) { create(:access_policy) }

    context "when no special conditions are set" do
      it "returns true" do
        expect(policy.check_conditions({})).to be true
      end
    end

    context "when require_mfa is true and context lacks mfa" do
      before { policy.update!(conditions: { "require_mfa" => true }) }

      it "returns false" do
        expect(policy.check_conditions({ mfa: false })).to be false
      end
    end

    context "when allowed_ips is set and ip matches" do
      before { policy.update!(conditions: { "allowed_ips" => ["192.168.1.1"] }) }

      it "returns true" do
        expect(policy.check_conditions({ ip: "192.168.1.1" })).to be true
      end
    end

    context "when allowed_ips is set and ip does not match" do
      before { policy.update!(conditions: { "allowed_ips" => ["192.168.1.1"] }) }

      it "returns false" do
        expect(policy.check_conditions({ ip: "10.0.0.1" })).to be false
      end
    end
  end
end
