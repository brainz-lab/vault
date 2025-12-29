class EncryptionKey < ApplicationRecord
  belongs_to :project, optional: true  # nil for global keys
  belongs_to :previous_key, class_name: "EncryptionKey", optional: true

  has_many :successor_keys, class_name: "EncryptionKey", foreign_key: :previous_key_id

  validates :key_id, presence: true, uniqueness: { scope: :project_id }
  validates :key_type, presence: true
  validates :encrypted_key, presence: true
  validates :encryption_iv, presence: true

  STATUSES = %w[active rotating retired].freeze

  scope :active, -> { where(status: "active") }
  scope :for_project, ->(project) { where(project: project) }

  def active?
    status == "active"
  end

  def retired?
    status == "retired"
  end

  def rotating?
    status == "rotating"
  end

  def retire!
    update!(status: "retired", retired_at: Time.current)
  end

  def activate!
    update!(status: "active", activated_at: Time.current)
  end
end
