class AuditLog < ApplicationRecord
  belongs_to :project

  validates :action, presence: true
  validates :resource_type, presence: true
  validates :actor_type, presence: true

  scope :recent, -> { order(created_at: :desc) }
  scope :for_secret, ->(secret) { where(resource_type: "secret", resource_id: secret.id) }
  scope :by_actor, ->(type, id) { where(actor_type: type, actor_id: id) }
  scope :for_environment, ->(env) { where(environment: env) }

  ACTIONS = %w[read create update delete archive rotate rollback access_granted access_denied].freeze
  RESOURCE_TYPES = %w[secret environment token policy folder].freeze
  ACTOR_TYPES = %w[user token system].freeze

  def self.log_access(secret, environment, token:, ip:, success: true, error: nil)
    create!(
      project: secret.project,
      action: success ? "read" : "access_denied",
      resource_type: "secret",
      resource_id: secret.id,
      resource_path: secret.path,
      environment: environment.name,
      actor_type: "token",
      actor_id: token.id,
      actor_name: token.name,
      ip_address: ip,
      success: success,
      error_message: error
    )
  end

  # Make it append-only (enforced via database rules too)
  def readonly?
    persisted?
  end

  def destroy
    raise ActiveRecord::ReadOnlyRecord, "Audit logs are immutable"
  end

  def delete
    raise ActiveRecord::ReadOnlyRecord, "Audit logs are immutable"
  end
end
