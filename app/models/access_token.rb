class AccessToken < ApplicationRecord
  belongs_to :project

  validates :name, presence: true
  validates :token_digest, presence: true, uniqueness: { scope: :project_id }

  before_validation :generate_token, on: :create

  attr_accessor :plain_token  # Only available on create

  scope :active, -> { where(active: true, revoked_at: nil).where("expires_at IS NULL OR expires_at > ?", Time.current) }

  def self.authenticate(token)
    return nil unless token.present?

    prefix = token[0..7]
    digest = Digest::SHA256.hexdigest(token)

    find_by(token_prefix: prefix, token_digest: digest, active: true)
      &.tap { |t| t.update_columns(last_used_at: Time.current, use_count: t.use_count + 1) }
  end

  def can_access?(secret, environment, permission: "read")
    return false unless active? && !revoked?
    return false if expired?

    # Check environment access
    if environments.any?
      return false unless environments.include?(environment.slug)
    end

    # Check path access
    if paths.any?
      return false unless paths.any? { |pattern| File.fnmatch?(pattern, secret.path) }
    end

    # Check permission
    permissions.include?(permission)
  end

  def revoke!(by: nil)
    update!(
      active: false,
      revoked_at: Time.current,
      revoked_by: by
    )
  end

  def expired?
    expires_at.present? && expires_at < Time.current
  end

  def revoked?
    revoked_at.present?
  end

  # Verify a raw token matches this access token
  def authenticate(raw_token)
    return false unless raw_token.present?

    digest = Digest::SHA256.hexdigest(raw_token)
    if token_digest == digest
      update_columns(last_used_at: Time.current, use_count: use_count + 1)
      true
    else
      false
    end
  end

  # Check if token has a specific permission
  def has_permission?(permission)
    permissions.include?(permission.to_s)
  end

  private

  def generate_token
    self.plain_token = SecureRandom.urlsafe_base64(32)
    self.token_prefix = plain_token[0..7]
    self.token_digest = Digest::SHA256.hexdigest(plain_token)
  end
end
