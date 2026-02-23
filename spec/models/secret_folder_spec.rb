require "rails_helper"

RSpec.describe SecretFolder, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:project) }
    it { is_expected.to belong_to(:parent_folder).class_name("SecretFolder").optional }
    it { is_expected.to have_many(:secrets).dependent(:nullify) }
    it { is_expected.to have_many(:child_folders) }
  end

  describe "validations" do
    subject { build(:secret_folder) }

    it { is_expected.to validate_presence_of(:name) }
    it "auto-generates path from name via set_path callback" do
      folder = create(:secret_folder, name: "configs", path: nil)
      expect(folder.path).to be_present
    end

    it "enforces uniqueness of path scoped to project" do
      existing = create(:secret_folder)
      duplicate = build(:secret_folder, project: existing.project, path: existing.path)
      duplicate.valid?
      expect(duplicate.errors[:path]).to be_present
    end
  end

  describe "callbacks" do
    describe "before_validation :set_path" do
      it "sets path from full_path when path is nil" do
        folder = build(:secret_folder, name: "configs", path: nil)
        folder.valid?
        expect(folder.path).to be_present
      end

      it "builds path as /name for root folders" do
        folder = build(:secret_folder, name: "configs", parent_folder: nil)
        folder.valid?
        expect(folder.path).to eq("/configs")
      end

      it "builds nested path including parent path" do
        project       = create(:project)
        parent_folder = create(:secret_folder, project: project, name: "parent")
        child_folder  = build(:secret_folder, project: project, name: "child", parent_folder: parent_folder)
        child_folder.valid?
        expect(child_folder.path).to include("parent")
        expect(child_folder.path).to include("child")
      end
    end
  end

  describe "scopes" do
    let(:project) { create(:project) }

    describe ".root" do
      let!(:root_folder)   { create(:secret_folder, project: project, parent_folder: nil) }
      let!(:nested_folder) { create(:secret_folder, project: project, parent_folder: root_folder) }

      it "returns only root-level folders" do
        expect(project.secret_folders.root).to include(root_folder)
        expect(project.secret_folders.root).not_to include(nested_folder)
      end
    end

    describe ".ordered" do
      it "returns folders in a defined order" do
        folder_b = create(:secret_folder, project: project, name: "beta")
        folder_a = create(:secret_folder, project: project, name: "alpha")
        expect(project.secret_folders.ordered).to be_present
      end
    end
  end

  describe "#full_path" do
    let(:project) { create(:project) }

    it "returns /parameterized-name for root folder" do
      folder = build(:secret_folder, project: project, name: "My Configs", parent_folder: nil)
      expect(folder.full_path).to eq("/my-configs")
    end

    it "returns parent_path/parameterized-name for nested folder" do
      parent = create(:secret_folder, project: project, name: "parent")
      child  = build(:secret_folder, project: project, name: "child", parent_folder: parent)
      expect(child.full_path).to eq("#{parent.path}/child")
    end
  end

  describe "#secrets_count" do
    let(:project) { create(:project) }
    let(:folder)  { create(:secret_folder, project: project) }

    it "returns the count of active secrets in the folder" do
      create(:secret, project: project, secret_folder: folder, archived: false)
      expect(folder.secrets_count).to eq(1)
    end

    it "does not count archived secrets" do
      create(:secret, project: project, secret_folder: folder, archived: true, archived_at: Time.current)
      expect(folder.secrets_count).to eq(0)
    end

    it "returns 0 when folder has no secrets" do
      expect(folder.secrets_count).to eq(0)
    end
  end
end
