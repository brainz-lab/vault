require "rails_helper"

RSpec.describe ProviderKey, type: :model do
  describe "constants" do
    it "defines PROVIDERS" do
      expect(ProviderKey::PROVIDERS).to eq(%w[openai anthropic google azure cohere mistral groq replicate huggingface])
    end

    it "defines MODEL_TYPES" do
      expect(ProviderKey::MODEL_TYPES).to eq(%w[llm embedding image tts stt video code])
    end
  end

  describe "associations" do
    it { is_expected.to belong_to(:project).optional }
  end

  describe "validations" do
    subject { build(:provider_key) }

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:provider) }
    it { is_expected.to validate_presence_of(:model_type) }
    it { is_expected.to validate_presence_of(:encrypted_key) }
    it { is_expected.to validate_presence_of(:encryption_iv) }
    it { is_expected.to validate_presence_of(:encryption_key_id) }
    it { is_expected.to validate_inclusion_of(:provider).in_array(ProviderKey::PROVIDERS) }
    it { is_expected.to validate_inclusion_of(:model_type).in_array(ProviderKey::MODEL_TYPES) }

    describe "global_or_project validation" do
      it "is invalid when global is true and project_id is set" do
        key = build(:provider_key, global: true, project: create(:project))
        key.valid?
        expect(key.errors[:base]).to be_present
      end

      it "is invalid when global is false and project_id is nil" do
        key = build(:provider_key, global: false, project: nil)
        key.valid?
        expect(key.errors[:base]).to be_present
      end

      it "is valid when global is true and project_id is nil" do
        key = build(:provider_key, global: true, project: nil)
        expect(key).to be_valid
      end

      it "is valid when global is false and project_id is set" do
        key = build(:provider_key, global: false, project: create(:project))
        expect(key).to be_valid
      end
    end

    describe "unique_active_key_per_scope validation" do
      let(:project) { create(:project) }

      it "is invalid when a duplicate priority exists for the same provider and scope" do
        create(:provider_key, project: project, provider: "openai", model_type: "llm", priority: 1, active: true)
        duplicate = build(:provider_key, project: project, provider: "openai", model_type: "llm", priority: 1, active: true)
        duplicate.valid?
        expect(duplicate.errors[:priority]).to be_present
      end

      it "is valid when priorities differ for the same provider and scope" do
        create(:provider_key, project: project, provider: "openai", model_type: "llm", priority: 1, active: true)
        second = build(:provider_key, project: project, provider: "openai", model_type: "llm", priority: 2, active: true)
        expect(second).to be_valid
      end
    end
  end

  describe "scopes" do
    let(:project) { create(:project) }

    describe ".active" do
      let!(:active_key)   { create(:provider_key, project: project, active: true) }
      let!(:inactive_key) { create(:provider_key, project: project, active: false) }

      it "returns only active keys" do
        expect(ProviderKey.active).to include(active_key)
        expect(ProviderKey.active).not_to include(inactive_key)
      end
    end

    describe ".global_keys" do
      let!(:global_key)  { create(:provider_key, global: true, project: nil) }
      let!(:project_key) { create(:provider_key, global: false, project: project) }

      it "returns only global keys" do
        expect(ProviderKey.global_keys).to include(global_key)
        expect(ProviderKey.global_keys).not_to include(project_key)
      end
    end

    describe ".for_project" do
      let(:other_project)  { create(:project) }
      let!(:project_key)   { create(:provider_key, project: project) }
      let!(:other_key)     { create(:provider_key, project: other_project) }

      it "returns keys scoped to the given project" do
        expect(ProviderKey.for_project(project.id)).to include(project_key)
        expect(ProviderKey.for_project(project.id)).not_to include(other_key)
      end
    end

    describe ".for_provider" do
      let!(:openai_key)     { create(:provider_key, project: project, provider: "openai") }
      let!(:anthropic_key)  { create(:provider_key, project: project, provider: "anthropic") }

      it "returns keys for the specified provider" do
        expect(ProviderKey.for_provider("openai")).to include(openai_key)
        expect(ProviderKey.for_provider("openai")).not_to include(anthropic_key)
      end
    end

    describe ".by_priority" do
      let!(:low_priority)  { create(:provider_key, project: project, provider: "openai", model_type: "llm", priority: 10) }
      let!(:high_priority) { create(:provider_key, project: project, provider: "openai", model_type: "embedding", priority: 1) }

      it "returns keys ordered by priority descending" do
        keys = ProviderKey.by_priority
        priorities = keys.map(&:priority)
        expect(priorities).to eq(priorities.sort.reverse)
      end
    end
  end

  describe ".create_encrypted" do
    let(:project) { create(:project) }

    it "creates a ProviderKey with encrypted api_key" do
      expect {
        ProviderKey.create_encrypted(
          project: project,
          name: "OpenAI Key",
          provider: "openai",
          model_type: "llm",
          api_key: "sk-test123",
          priority: 1
        )
      }.to change(ProviderKey, :count).by(1)
    end

    it "stores the key in encrypted form" do
      key = ProviderKey.create_encrypted(
        project: project,
        name: "OpenAI Key",
        provider: "openai",
        model_type: "llm",
        api_key: "sk-test123",
        priority: 1
      )
      expect(key.encrypted_key).not_to eq("sk-test123")
    end
  end

  describe ".resolve" do
    let(:project)     { create(:project) }
    let!(:project_key) do
      create(:provider_key,
        project: project,
        provider: "openai",
        model_type: "llm",
        active: true,
        priority: 1
      )
    end

    it "returns a project-level key when available" do
      result = ProviderKey.resolve(project_id: project.id, provider: "openai", model_type: "llm")
      expect(result).to eq(project_key)
    end

    context "when no project key exists but a global key does" do
      let(:other_project) { create(:project) }
      let!(:global_key) do
        create(:provider_key,
          global: true,
          project: nil,
          provider: "anthropic",
          model_type: "llm",
          active: true,
          priority: 1
        )
      end

      it "falls back to the global key" do
        result = ProviderKey.resolve(project_id: other_project.id, provider: "anthropic", model_type: "llm")
        expect(result).to eq(global_key)
      end
    end

    it "returns nil when no key exists for the provider" do
      result = ProviderKey.resolve(project_id: project.id, provider: "groq", model_type: "llm")
      expect(result).to be_nil
    end
  end

  describe "#decrypt" do
    let(:key) { create(:provider_key) }

    it "returns the decrypted API key string" do
      expect(key.decrypt).to be_a(String)
      expect(key.decrypt).not_to be_empty
    end
  end

  describe "#masked_key" do
    let(:key) { create(:provider_key) }

    it "returns a masked representation" do
      masked = key.masked_key
      expect(masked).to be_a(String)
      expect(masked).to include("...")
    end

    it "does not reveal the full key" do
      original = key.decrypt
      masked   = key.masked_key
      expect(masked).not_to eq(original)
    end
  end

  describe "#expired?" do
    it "returns false when expires_at is nil" do
      key = build(:provider_key, expires_at: nil)
      expect(key.expired?).to be false
    end

    it "returns true when expires_at is in the past" do
      key = build(:provider_key, expires_at: 1.day.ago)
      expect(key.expired?).to be true
    end

    it "returns false when expires_at is in the future" do
      key = build(:provider_key, expires_at: 1.day.from_now)
      expect(key.expired?).to be false
    end
  end

  describe "#deactivate!" do
    let(:key) { create(:provider_key, active: true) }

    it "sets active to false" do
      key.deactivate!
      expect(key.reload.active).to be false
    end
  end

  describe "#activate!" do
    let(:key) { create(:provider_key, active: false) }

    it "sets active to true" do
      key.activate!
      expect(key.reload.active).to be true
    end
  end

  describe "#record_usage!" do
    let(:key) { create(:provider_key) }

    it "updates last_used_at" do
      expect { key.record_usage! }.to change { key.reload.last_used_at }
    end

    it "increments usage_count" do
      expect { key.record_usage! }.to change { key.reload.usage_count }.by(1)
    end
  end
end
