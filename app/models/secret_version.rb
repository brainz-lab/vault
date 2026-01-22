class SecretVersion < ApplicationRecord
  belongs_to :secret, counter_cache: :versions_count
  belongs_to :secret_environment

  validates :version, presence: true, numericality: { greater_than: 0 }
  validates :encrypted_value, presence: true
  validates :encryption_iv, presence: true

  after_create :audit_creation

  def decrypt
    Encryption::Encryptor.decrypt(
      encrypted_value,
      iv: encryption_iv,
      key_id: encryption_key_id,
      project_id: secret.project_id
    )
  end

  def expired?
    expires_at.present? && expires_at < Time.current
  end

  def value_preview
    decrypted = decrypt
    if decrypted.length > 8
      "#{decrypted[0..3]}...#{decrypted[-4..]}"
    else
      "••••••••"
    end
  rescue
    "••••••••"
  end

  # Check if this version has an OTP secret stored
  def has_otp_secret?
    encrypted_otp_secret.present? && otp_secret_iv.present?
  end

  # Decrypt the OTP secret
  def decrypt_otp_secret
    return nil unless has_otp_secret?

    Encryption::Encryptor.decrypt(
      encrypted_otp_secret,
      iv: otp_secret_iv,
      key_id: otp_secret_key_id,
      project_id: secret.project_id
    )
  end

  # Preview of OTP secret (masked)
  def otp_secret_preview
    return nil unless has_otp_secret?

    otp_secret = decrypt_otp_secret
    if otp_secret.length > 8
      "#{otp_secret[0..3]}...#{otp_secret[-4..]}"
    else
      "••••••••"
    end
  rescue
    "••••••••"
  end

  private

  def audit_creation
    AuditLog.create!(
      project: secret.project,
      action: version == 1 ? "create" : "update",
      resource_type: "secret",
      resource_id: secret.id,
      resource_path: secret.path,
      environment: secret_environment.name,
      actor_type: created_by.present? ? "user" : "system",
      actor_id: created_by,
      metadata: {
        version: version,
        previous_version: version > 1 ? version - 1 : nil,
        change_note: change_note
      }
    )
  end
end
