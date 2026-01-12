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

  def self.log_access(secret = nil, environment = nil, token: nil, ip: nil, success: true, error: nil, **attrs)
    # Handle flexible call signatures
    if secret && token
      create!(
        project: secret.project,
        action: success ? "read" : "access_denied",
        resource_type: "secret",
        resource_id: secret.id,
        resource_path: secret.path,
        environment: environment&.name || attrs[:environment],
        actor_type: "token",
        actor_id: token.id,
        actor_name: token.name,
        ip_address: ip,
        success: success,
        error_message: error
      )
    else
      # Generic logging from controller
      create!(
        project: attrs[:project],
        action: attrs[:action],
        resource_type: attrs[:resource_type] || "secret",
        resource_id: attrs[:secret]&.id || attrs[:resource_id],
        resource_path: attrs[:secret]&.path || attrs[:resource_path],
        environment: attrs[:environment],
        actor_type: attrs[:actor_type] || "token",
        actor_id: attrs[:actor_id],
        actor_name: attrs[:actor_name],
        ip_address: attrs[:ip_address],
        user_agent: attrs[:user_agent],
        metadata: attrs[:details] || {},
        success: success,
        error_message: error
      )
    end
  end

  # Extract secret key from resource_path (no query needed)
  # Path format: /folder/SECRET_KEY or /SECRET_KEY
  def secret_key
    return nil unless resource_type == "secret" && resource_path.present?
    resource_path.split("/").last
  end

  # Fetch associated secret (if resource_type is secret)
  # WARNING: This triggers a query - prefer secret_key for display
  def secret
    return nil unless resource_type == "secret" && resource_id.present?
    @secret ||= project.secrets.find_by(id: resource_id)
  end

  # Make it append-only (enforced via database rules too)
  # Allow deletion in test environment for fixture cleanup
  def readonly?
    return false if Rails.env.test?
    persisted?
  end

  def destroy
    return super if Rails.env.test?
    raise ActiveRecord::ReadOnlyRecord, "Audit logs are immutable"
  end

  def delete
    return super if Rails.env.test?
    raise ActiveRecord::ReadOnlyRecord, "Audit logs are immutable"
  end
end
