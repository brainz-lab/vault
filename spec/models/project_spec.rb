require "rails_helper"

RSpec.describe Project, type: :model do
  describe "associations" do
    it { is_expected.to have_many(:secret_environments).dependent(:destroy) }
    it { is_expected.to have_many(:secret_folders).dependent(:destroy) }
    it { is_expected.to have_many(:secrets).dependent(:destroy) }
    it { is_expected.to have_many(:access_tokens).dependent(:destroy) }
    it { is_expected.to have_many(:access_policies).dependent(:destroy) }
    it { is_expected.to have_many(:audit_logs).dependent(:destroy) }
    it { is_expected.to have_many(:encryption_keys).dependent(:destroy) }
    it { is_expected.to have_many(:ssh_client_keys).dependent(:destroy) }
    it { is_expected.to have_many(:ssh_server_keys).dependent(:destroy) }
    it { is_expected.to have_many(:ssh_connections).dependent(:destroy) }
  end

  describe "validations" do
    subject { build(:project) }

    it "auto-generates platform_project_id when nil (callback)" do
      project = create(:project, platform_project_id: nil)
      expect(project.platform_project_id).to be_present
    end

    it "enforces uniqueness of platform_project_id" do
      existing = create(:project)
      duplicate = build(:project, platform_project_id: existing.platform_project_id)
      duplicate.valid?
      expect(duplicate.errors[:platform_project_id]).to be_present
    end
    it { is_expected.to validate_uniqueness_of(:api_key).allow_nil }
    it { is_expected.to validate_uniqueness_of(:ingest_key).allow_nil }
  end

  describe "callbacks" do
    describe "before_validation :ensure_platform_project_id" do
      it "sets a UUID for platform_project_id if nil" do
        project = build(:project, platform_project_id: nil)
        project.valid?
        expect(project.platform_project_id).to be_present
        expect(project.platform_project_id).to match(/\A[0-9a-f\-]{36}\z/i)
      end

      it "does not overwrite an existing platform_project_id" do
        existing_id = SecureRandom.uuid
        project = build(:project, platform_project_id: existing_id)
        project.valid?
        expect(project.platform_project_id).to eq(existing_id)
      end
    end

    describe "before_create :generate_keys" do
      it "sets api_key with vlt_api_ prefix" do
        project = create(:project)
        expect(project.api_key).to start_with("vlt_api_")
      end

      it "sets ingest_key with vlt_ingest_ prefix" do
        project = create(:project)
        expect(project.ingest_key).to start_with("vlt_ingest_")
      end
    end

    describe "after_create :create_default_environments" do
      it "creates Development, Staging and Production environments" do
        project = create(:project)
        env_names = project.secret_environments.pluck(:name)
        expect(env_names).to include("Development", "Staging", "Production")
      end
    end
  end

  describe "scopes" do
    let!(:active_project)   { create(:project) }
    let!(:archived_project) { create(:project, archived_at: 1.day.ago) }

    describe ".active" do
      it "returns only non-archived projects" do
        expect(Project.active).to include(active_project)
        expect(Project.active).not_to include(archived_project)
      end
    end

    describe ".archived" do
      it "returns only archived projects" do
        expect(Project.archived).to include(archived_project)
        expect(Project.archived).not_to include(active_project)
      end
    end
  end

  describe ".find_or_create_for_platform!" do
    let(:platform_id) { SecureRandom.uuid }

    it "creates a new project when one does not exist" do
      expect {
        Project.find_or_create_for_platform!(
          platform_project_id: platform_id,
          name: "New Project",
          environment: "production"
        )
      }.to change(Project, :count).by(1)
    end

    it "returns an existing project when it already exists" do
      existing = create(:project, platform_project_id: platform_id, name: "Existing")
      found = Project.find_or_create_for_platform!(
        platform_project_id: platform_id,
        name: "Existing",
        environment: "production"
      )
      expect(found.id).to eq(existing.id)
    end
  end

  describe ".find_by_api_key" do
    let!(:project) { create(:project) }

    it "finds a project by api_key" do
      expect(Project.find_by_api_key(project.api_key)).to eq(project)
    end

    it "finds a project by ingest_key" do
      expect(Project.find_by_api_key(project.ingest_key)).to eq(project)
    end

    it "returns nil when key does not match" do
      expect(Project.find_by_api_key("vlt_api_unknown")).to be_nil
    end
  end
end
