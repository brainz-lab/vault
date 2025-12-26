class Secret < ApplicationRecord
  belongs_to :project
  belongs_to :secret_folder, optional: true

  has_many :versions, class_name: "SecretVersion", dependent: :destroy

  validates :key, presence: true, format: {
    with: /\A[A-Z][A-Z0-9_]*\z/,
    message: "must be uppercase with underscores (e.g., DATABASE_URL)"
  }
  validates :path, presence: true, uniqueness: { scope: :project_id }

  before_validation :set_path

  scope :active, -> { where(archived: false) }
  scope :in_folder, ->(folder) { where(secret_folder: folder) }
  scope :with_tag, ->(key, value) { where("tags->>? = ?", key, value) }

  def current_version(environment)
    versions.where(secret_environment: environment, current: true).first
  end

  def value(environment)
    version = current_version(environment)
    return nil unless version

    version.decrypt
  end

  def set_value(environment, value, user: nil, note: nil)
    ActiveRecord::Base.transaction do
      # Mark previous version as not current
      versions.where(secret_environment: environment, current: true)
              .update_all(current: false)

      # Create new version
      version_number = versions.where(secret_environment: environment).maximum(:version).to_i + 1

      encrypted_data = Encryption::Encryptor.encrypt(value, project_id: project_id)

      versions.create!(
        secret_environment: environment,
        version: version_number,
        current: true,
        encrypted_value: encrypted_data.ciphertext,
        encryption_iv: encrypted_data.iv,
        encryption_key_id: encrypted_data.key_id,
        value_length: value.length,
        value_hash: Digest::SHA256.hexdigest(value),
        created_by: user,
        change_note: note
      )
    end
  end

  def version_history(environment, limit: 10)
    versions.where(secret_environment: environment)
            .order(version: :desc)
            .limit(limit)
  end

  def rollback(environment, to_version:, user: nil)
    target = versions.find_by!(secret_environment: environment, version: to_version)

    ActiveRecord::Base.transaction do
      versions.where(secret_environment: environment, current: true)
              .update_all(current: false)

      new_version = versions.create!(
        secret_environment: environment,
        version: versions.where(secret_environment: environment).maximum(:version) + 1,
        current: true,
        encrypted_value: target.encrypted_value,
        encryption_iv: target.encryption_iv,
        encryption_key_id: target.encryption_key_id,
        value_length: target.value_length,
        value_hash: target.value_hash,
        created_by: user,
        change_note: "Rollback to version #{to_version}"
      )

      new_version
    end
  end

  def archive!(user: nil)
    update!(archived: true, archived_at: Time.current)

    AuditLog.create!(
      project: project,
      action: "archive",
      resource_type: "secret",
      resource_id: id,
      resource_path: path,
      actor_type: user ? "user" : "system",
      actor_id: user,
      actor_name: user || "system"
    )
  end

  private

  def set_path
    folder_path = secret_folder&.path || ""
    self.path = "#{folder_path}/#{key}".gsub(/^\/+/, "/")
  end
end
