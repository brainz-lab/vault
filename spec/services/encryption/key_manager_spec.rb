require "rails_helper"

RSpec.describe Encryption::KeyManager do
  before do
    setup_master_key
    @project = create(:project)
  end

  describe ".current_key" do
    it "returns existing active key" do
      described_class.create_key(@project.id)

      key = described_class.current_key(@project.id)

      expect(key).to be_a(described_class::KeyWrapper)
      expect(key.key_id).to be_present
      expect(key.raw_key).to be_present
      expect(key.raw_key.bytesize).to eq(32)
    end

    it "creates new key if none exists" do
      project = create(:project)

      key = described_class.current_key(project.id)

      expect(key).to be_a(described_class::KeyWrapper)
      expect(key.record.project_id).to eq(project.id)
      expect(key.record.status).to eq("active")
    end
  end

  describe ".get_key" do
    it "retrieves key by key_id" do
      created_key = described_class.create_key(@project.id)

      key = described_class.get_key(created_key.key_id, project_id: @project.id)

      expect(key.key_id).to eq(created_key.key_id)
      expect(key.raw_key).to eq(created_key.raw_key)
    end

    it "raises error for non-existent key" do
      expect {
        described_class.get_key("non-existent-key-id")
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe ".create_key" do
    it "creates new encryption key" do
      project = create(:project)
      initial_count = EncryptionKey.count

      key = described_class.create_key(project.id)

      expect(EncryptionKey.count).to eq(initial_count + 1)
      expect(key).to be_a(described_class::KeyWrapper)
      expect(key.record.project_id).to eq(project.id)
      expect(key.record.status).to eq("active")
      expect(key.record.key_type).to eq("aes-256-gcm")
    end

    it "stores encrypted key data" do
      project = create(:project)
      key = described_class.create_key(project.id)

      expect(key.record.encrypted_key).to be_present
      expect(key.record.encryption_iv).to be_present
      expect(key.record.kms_provider).to eq("local")
    end
  end

  describe ".rotate_key" do
    it "creates new key and retires old" do
      project = create(:project)
      old_key = described_class.current_key(project.id)
      old_key_id = old_key.key_id

      new_key = described_class.rotate_key(project.id)

      expect(new_key.key_id).not_to eq(old_key_id)
      expect(new_key.record.status).to eq("active")

      old_key_record = EncryptionKey.find_by(key_id: old_key_id)
      expect(old_key_record.status).to eq("retired")
      expect(old_key_record.retired_at).to be_present
    end
  end

  describe "KeyWrapper" do
    it "exposes key_id from record" do
      key = described_class.current_key(@project.id)

      expect(key.key_id).to eq(key.record.key_id)
    end

    it "stores 32-byte raw key" do
      key = described_class.current_key(@project.id)

      expect(key.raw_key.bytesize).to eq(32)
    end
  end
end
