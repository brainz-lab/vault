class ProviderKey < ApplicationRecord
  belongs_to :project, optional: true

  PROVIDERS = %w[openai anthropic google azure cohere mistral groq replicate huggingface].freeze
  MODEL_TYPES = %w[llm embedding image tts stt video code].freeze

  validates :name, presence: true
  validates :provider, presence: true, inclusion: { in: PROVIDERS }
  validates :model_type, presence: true, inclusion: { in: MODEL_TYPES }
  validates :encrypted_key, presence: true
  validates :encryption_iv, presence: true
  validates :encryption_key_id, presence: true

  validate :global_or_project
  validate :unique_active_key_per_scope

  scope :active, -> { where(active: true) }
  scope :global_keys, -> { where(global: true, project_id: nil) }
  scope :for_project, ->(project) { where(project: project) }
  scope :for_provider, ->(provider) { where(provider: provider) }
  scope :by_priority, -> { order(priority: :desc, created_at: :asc) }

  before_validation :extract_key_prefix, on: :create
  before_validation :set_encryption_project

  # Encrypt the API key before storing
  def self.create_encrypted(attributes)
    plaintext_key = attributes.delete(:api_key) || attributes.delete(:key)
    raise ArgumentError, "api_key is required" unless plaintext_key.present?

    project_id = attributes[:project_id] || attributes[:project]&.id
    encrypted_data = Encryption::Encryptor.encrypt(plaintext_key, project_id: project_id)

    create!(attributes.merge(
      encrypted_key: encrypted_data.ciphertext,
      encryption_iv: encrypted_data.iv,
      encryption_key_id: encrypted_data.key_id,
      key_prefix: extract_prefix(plaintext_key)
    ))
  end

  # Decrypt and return the API key
  def decrypt
    Encryption::Encryptor.decrypt(
      encrypted_key,
      iv: encryption_iv,
      key_id: encryption_key_id,
      project_id: project_id
    )
  end

  # Get the best available key for a project and provider
  def self.resolve(project_id:, provider:, model_type: "llm")
    # First try project-specific key
    key = for_project(Project.find_by(id: project_id))
            .for_provider(provider)
            .where(model_type: model_type)
            .active
            .by_priority
            .first

    # Fall back to global key
    key ||= global_keys
              .for_provider(provider)
              .where(model_type: model_type)
              .active
              .by_priority
              .first

    key
  end

  # Get decrypted key value for a project and provider
  def self.get_key(project_id:, provider:, model_type: "llm")
    key = resolve(project_id: project_id, provider: provider, model_type: model_type)
    return nil unless key

    key.record_usage!
    key.decrypt
  end

  def record_usage!
    update_columns(
      last_used_at: Time.current,
      usage_count: usage_count + 1
    )
  end

  def masked_key
    return nil unless key_prefix.present?
    "#{key_prefix}...#{key_prefix.last(4)}"
  end

  def expired?
    expires_at.present? && expires_at < Time.current
  end

  def deactivate!
    update!(active: false)
  end

  def activate!
    update!(active: true)
  end

  private

  def self.extract_prefix(key)
    return nil unless key.present?
    # For OpenAI: sk-proj-xxx...xxx -> sk-proj-xxx
    # For Anthropic: sk-ant-xxx...xxx -> sk-ant-xxx
    key[0, 12]
  end

  def extract_key_prefix
    # Already set by create_encrypted
  end

  def set_encryption_project
    # Use project's encryption key if project-scoped, otherwise use global key
  end

  def global_or_project
    if global? && project_id.present?
      errors.add(:base, "A key cannot be both global and project-specific")
    end

    if !global? && project_id.blank?
      errors.add(:base, "Non-global keys must belong to a project")
    end
  end

  def unique_active_key_per_scope
    return unless active?

    scope = self.class.active.for_provider(provider).where(model_type: model_type)

    if global?
      scope = scope.global_keys
    else
      scope = scope.for_project(project)
    end

    scope = scope.where.not(id: id) if persisted?

    # Allow multiple keys but they should have different priorities
    if scope.where(priority: priority).exists?
      errors.add(:priority, "must be unique for this provider and scope")
    end
  end
end
