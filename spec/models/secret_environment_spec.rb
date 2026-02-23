require "rails_helper"

RSpec.describe SecretEnvironment, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:project) }
    it { is_expected.to belong_to(:parent_environment).class_name("SecretEnvironment").optional }
    it { is_expected.to have_many(:secret_versions).dependent(:destroy) }
    it { is_expected.to have_many(:child_environments) }
  end

  describe "validations" do
    subject { build(:secret_environment) }

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_uniqueness_of(:name).scoped_to(:project_id) }
    it "auto-generates slug from name via set_slug callback" do
      env = create(:secret_environment, name: "My Environment", slug: nil)
      expect(env.slug).to be_present
    end

    it { is_expected.to validate_uniqueness_of(:slug).scoped_to(:project_id) }

    describe "slug format" do
      it "accepts lowercase alphanumeric slugs with hyphens" do
        env = build(:secret_environment, slug: "my-environment-1")
        expect(env).to be_valid
      end

      it "rejects slugs with uppercase letters" do
        env = build(:secret_environment, slug: "MyEnv")
        env.valid?
        expect(env.errors[:slug]).to be_present
      end

      it "rejects slugs with underscores" do
        env = build(:secret_environment, slug: "my_env")
        env.valid?
        expect(env.errors[:slug]).to be_present
      end

      it "rejects slugs with spaces" do
        env = build(:secret_environment, slug: "my env")
        env.valid?
        expect(env.errors[:slug]).to be_present
      end
    end
  end

  describe "callbacks" do
    describe "before_validation :set_slug" do
      it "generates slug from name when slug is nil" do
        env = build(:secret_environment, name: "My Environment", slug: nil)
        env.valid?
        expect(env.slug).to be_present
        expect(env.slug).to match(/\A[a-z0-9\-]+\z/)
      end

      it "does not overwrite an existing slug" do
        existing_slug = "custom-slug"
        env = build(:secret_environment, slug: existing_slug)
        env.valid?
        expect(env.slug).to eq(existing_slug)
      end
    end
  end

  describe "scopes" do
    let(:project) { create(:project) }

    describe ".ordered" do
      it "returns environments in non-decreasing position order" do
        ordered = project.secret_environments.ordered
        positions = ordered.map(&:position)
        expect(positions).to eq(positions.sort)
      end
    end
  end

  describe "#secrets_count" do
    let(:project)     { create(:project) }
    let(:environment) { project.secret_environments.find_by(name: "Development") }
    let(:secret)      { create(:secret, project: project) }

    it "counts current non-archived secret versions in this environment" do
      create(:secret_version, secret: secret, secret_environment: environment, version: 1)
      expect(environment.secrets_count).to eq(1)
    end

    it "does not count versions from archived secrets" do
      archived_secret = create(:secret, project: project, archived: true, archived_at: Time.current)
      create(:secret_version, secret: archived_secret, secret_environment: environment, version: 1)
      expect(environment.secrets_count).to eq(0)
    end
  end

  describe "#resolve_value" do
    let(:project)    { create(:project) }
    let(:parent_env) { project.secret_environments.find_by(name: "Production") }
    let(:child_env)  { create(:secret_environment, project: project, parent_environment: parent_env) }
    let(:secret)     { create(:secret, project: project) }

    context "when the environment has a version for the secret" do
      it "returns the value from this environment" do
        create(:secret_version, secret: secret, secret_environment: child_env, version: 1)
        result = child_env.resolve_value(secret)
        expect(result).not_to be_nil
      end
    end

    context "when the environment has no version but parent does" do
      it "falls back to the parent environment value" do
        create(:secret_version, secret: secret, secret_environment: parent_env, version: 1)
        result = child_env.resolve_value(secret)
        expect(result).not_to be_nil
      end
    end

    context "when neither environment nor parent has a version" do
      it "returns nil" do
        result = child_env.resolve_value(secret)
        expect(result).to be_nil
      end
    end
  end
end
