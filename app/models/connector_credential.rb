class ConnectorCredential < ApplicationRecord
  belongs_to :project
  belongs_to :connector

  validates :name, presence: true
  validates :auth_type, presence: true
  validates :encrypted_credentials, presence: true
  validates :encryption_iv, presence: true
  validates :encryption_key_id, presence: true
  validates :name, uniqueness: { scope: [ :project_id, :connector_id ] }
  validates :status, inclusion: { in: %w[active pending expired error revoked] }

  scope :active, -> { where(status: "active") }
  scope :for_connector, ->(connector) { where(connector: connector) }

  def self.create_encrypted(project:, connector:, name:, auth_type:, credentials:)
    encrypted = Encryption::Encryptor.encrypt(
      credentials.to_json,
      project_id: project.id
    )

    attrs = {
      project: project,
      connector: connector,
      name: name,
      auth_type: auth_type,
      encrypted_credentials: encrypted.ciphertext,
      encryption_iv: encrypted.iv,
      encryption_key_id: encrypted.key_id
    }

    create!(attrs)
  end

  def update_credentials(credentials)
    encrypted = Encryption::Encryptor.encrypt(
      credentials.to_json,
      project_id: project_id
    )

    update!(
      encrypted_credentials: encrypted.ciphertext,
      encryption_iv: encrypted.iv,
      encryption_key_id: encrypted.key_id,
      status: "active",
      error_message: nil
    )
  end

  def decrypt_credentials
    json = Encryption::Encryptor.decrypt(
      encrypted_credentials,
      iv: encryption_iv,
      key_id: encryption_key_id,
      project_id: project_id
    )
    JSON.parse(json, symbolize_names: true)
  end

  def store_refresh_token(token)
    encrypted = Encryption::Encryptor.encrypt(token, project_id: project_id)
    update!(
      encrypted_refresh_token: encrypted.ciphertext,
      refresh_token_iv: encrypted.iv,
      refresh_token_key_id: encrypted.key_id
    )
  end

  def decrypt_refresh_token
    return nil unless encrypted_refresh_token.present?

    Encryption::Encryptor.decrypt(
      encrypted_refresh_token,
      iv: refresh_token_iv,
      key_id: refresh_token_key_id,
      project_id: project_id
    )
  end

  def expired?
    status == "expired" || (token_expires_at.present? && token_expires_at < Time.current)
  end

  def mark_used!
    update_columns(last_used_at: Time.current, usage_count: usage_count + 1)
  end

  def mark_error!(message)
    update!(status: "error", error_message: message)
  end

  def mark_verified!
    update_columns(last_verified_at: Time.current, status: "active", error_message: nil)
  end

  def revoke!
    update!(status: "revoked")
  end

  def oauth?
    auth_type == "OAUTH2"
  end

  def needs_refresh?
    oauth? && token_expires_at.present? && token_expires_at < 10.minutes.from_now
  end

  def active_or_refresh!
    return unless oauth?
    return unless needs_refresh?
    return unless encrypted_refresh_token.present?

    refresher = Oauth::TokenRefresher.new(self)
    refresher.refresh!
  end

  def store_oauth_tokens!(access_token:, refresh_token: nil, expires_in: nil)
    transaction do
      credentials = decrypt_credentials.merge(access_token: access_token)
      update_credentials(credentials)

      store_refresh_token(refresh_token) if refresh_token.present?
      update!(token_expires_at: expires_in.to_i.seconds.from_now) if expires_in.present?
    end
  end

  def to_summary
    {
      id: id,
      connector_id: connector_id,
      name: name,
      auth_type: auth_type,
      status: status,
      last_verified_at: last_verified_at,
      last_used_at: last_used_at,
      usage_count: usage_count,
      created_at: created_at
    }
  end
end
