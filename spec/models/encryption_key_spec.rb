require "rails_helper"

RSpec.describe EncryptionKey, type: :model do
  describe "constants" do
    it "defines STATUSES" do
      expect(EncryptionKey::STATUSES).to eq(%w[active rotating retired])
    end
  end

  describe "associations" do
    it { is_expected.to belong_to(:project).optional }
    it { is_expected.to belong_to(:previous_key).class_name("EncryptionKey").optional }
    it { is_expected.to have_many(:successor_keys) }
  end

  describe "validations" do
    subject { create(:encryption_key) }

    it { is_expected.to validate_presence_of(:key_id) }
    it { is_expected.to validate_uniqueness_of(:key_id).scoped_to(:project_id) }
    it { is_expected.to validate_presence_of(:key_type) }
    it { is_expected.to validate_presence_of(:encrypted_key) }
    it { is_expected.to validate_presence_of(:encryption_iv) }
  end

  describe "scopes" do
    let(:project) { create(:project) }

    describe ".active" do
      let!(:active_key)   { create(:encryption_key, project: project, status: "active") }
      let!(:retired_key)  { create(:encryption_key, project: project, status: "retired") }
      let!(:rotating_key) { create(:encryption_key, project: project, status: "rotating") }

      it "returns only active keys" do
        expect(EncryptionKey.active).to include(active_key)
        expect(EncryptionKey.active).not_to include(retired_key)
        expect(EncryptionKey.active).not_to include(rotating_key)
      end
    end

    describe ".for_project" do
      let(:other_project)  { create(:project) }
      let!(:project_key)   { create(:encryption_key, project: project) }
      let!(:other_key)     { create(:encryption_key, project: other_project) }

      it "returns keys for the specified project" do
        expect(EncryptionKey.for_project(project.id)).to include(project_key)
        expect(EncryptionKey.for_project(project.id)).not_to include(other_key)
      end
    end
  end

  describe "#active?" do
    it "returns true when status is active" do
      key = build(:encryption_key, status: "active")
      expect(key.active?).to be true
    end

    it "returns false when status is not active" do
      key = build(:encryption_key, status: "retired")
      expect(key.active?).to be false
    end
  end

  describe "#retired?" do
    it "returns true when status is retired" do
      key = build(:encryption_key, status: "retired")
      expect(key.retired?).to be true
    end

    it "returns false when status is active" do
      key = build(:encryption_key, status: "active")
      expect(key.retired?).to be false
    end
  end

  describe "#rotating?" do
    it "returns true when status is rotating" do
      key = build(:encryption_key, status: "rotating")
      expect(key.rotating?).to be true
    end

    it "returns false when status is active" do
      key = build(:encryption_key, status: "active")
      expect(key.rotating?).to be false
    end
  end

  describe "#retire!" do
    let(:key) { create(:encryption_key, status: "active") }

    it "updates status to retired" do
      key.retire!
      expect(key.reload.status).to eq("retired")
    end

    it "sets retired_at timestamp" do
      key.retire!
      expect(key.reload.retired_at).to be_present
    end
  end

  describe "#activate!" do
    let(:key) { create(:encryption_key, status: "rotating") }

    it "updates status to active" do
      key.activate!
      expect(key.reload.status).to eq("active")
    end

    it "sets activated_at timestamp" do
      key.activate!
      expect(key.reload.activated_at).to be_present
    end
  end
end
