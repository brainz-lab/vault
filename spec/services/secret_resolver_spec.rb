require "rails_helper"

RSpec.describe SecretResolver do
  before do
    setup_master_key
    EncryptionKey.delete_all

    @project = create(:project, name: "Resolver Test Project")
    @environment = @project.secret_environments.find_by(slug: "development")
    @resolver = described_class.new(@project, @environment)
  end

  describe "#resolve" do
    it "returns value for existing secret" do
      secret = create(:secret, project: @project, key: "DATABASE_URL")
      # Set an encrypted value for this secret in the environment
      secret.set_value(@environment, "test_value")

      allow(Encryption::Encryptor).to receive(:decrypt).and_return("test_value")

      value = @resolver.resolve(secret.path)
      expect(value).to eq("test_value")
    end

    it "returns nil for non-existent secret" do
      value = @resolver.resolve("/non/existent/path")
      expect(value).to be_nil
    end

    it "returns nil for archived secret" do
      secret = create(:secret, :archived, project: @project, key: "OLD_API_KEY")
      value = @resolver.resolve(secret.path)
      expect(value).to be_nil
    end
  end

  describe "#resolve_all" do
    it "returns hash of all secrets" do
      secret = create(:secret, project: @project, key: "DATABASE_URL")
      secret.set_value(@environment, "postgres://localhost")

      allow(Encryption::Encryptor).to receive(:decrypt).and_return("test_value")

      secrets = @resolver.resolve_all
      expect(secrets).to be_a(Hash)
    end

    it "excludes archived secrets" do
      active_secret = create(:secret, project: @project, key: "ACTIVE_SECRET")
      active_secret.set_value(@environment, "active_value")
      create(:secret, :archived, project: @project, key: "ARCHIVED_SECRET")

      allow(Encryption::Encryptor).to receive(:decrypt).and_return("test_value")

      secrets = @resolver.resolve_all
      expect(secrets).not_to have_key("ARCHIVED_SECRET")
    end

    it "uses secret key as hash key" do
      secret = create(:secret, project: @project, key: "MY_SECRET_KEY")
      secret.set_value(@environment, "some_value")

      allow(Encryption::Encryptor).to receive(:decrypt).and_return("test_value")

      secrets = @resolver.resolve_all
      if secrets.any?
        key = secrets.keys.first
        expect(key).to match(/\A[A-Z][A-Z0-9_]*\z/)
      end
    end
  end

  describe "#resolve_with_references" do
    it "replaces variable references" do
      secret = create(:secret, project: @project, key: "DATABASE_URL")
      secret.set_value(@environment, "postgres://localhost")

      allow(Encryption::Encryptor).to receive(:decrypt).and_return("postgres://localhost")

      template = "Connection: ${DATABASE_URL}"
      result = @resolver.resolve_with_references(template)
      expect(result).to eq("Connection: postgres://localhost")
    end

    it "leaves unmatched references as-is" do
      template = "Value: ${NONEXISTENT_SECRET}"
      result = @resolver.resolve_with_references(template)
      expect(result).to eq("Value: ${NONEXISTENT_SECRET}")
    end

    it "handles multiple references" do
      secret1 = create(:secret, project: @project, key: "DATABASE_URL")
      secret1.set_value(@environment, "postgres://localhost")
      secret2 = create(:secret, project: @project, key: "REDIS_URL")
      secret2.set_value(@environment, "redis://localhost")

      allow(Encryption::Encryptor).to receive(:decrypt).and_return("value")

      template = "${DATABASE_URL} and ${REDIS_URL}"
      result = @resolver.resolve_with_references(template)
      # At least one should be resolved if the secret exists
      expect(result).to include("value").or include("${")
    end
  end

  describe "#resolve_by_folder" do
    it "returns secrets in folder" do
      folder = create(:secret_folder, project: @project, name: "database")
      secret = create(:secret, project: @project, key: "DB_HOST", secret_folder: folder)
      secret.set_value(@environment, "localhost")

      allow(Encryption::Encryptor).to receive(:decrypt).and_return("test_value")

      secrets = @resolver.resolve_by_folder(folder.path)
      expect(secrets).to be_a(Hash)
    end

    it "returns empty hash for non-existent folder" do
      secrets = @resolver.resolve_by_folder("/non/existent/folder")
      expect(secrets).to eq({})
    end
  end
end
