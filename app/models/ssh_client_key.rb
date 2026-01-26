class SshClientKey < ApplicationRecord
  belongs_to :project

  has_many :ssh_connections, dependent: :nullify

  validates :name, presence: true
  validates :key_type, presence: true, inclusion: { in: %w[rsa-2048 rsa-4096 ed25519] }
  validates :fingerprint, presence: true
  validates :public_key, presence: true
  validates :encrypted_private_key, presence: true
  validates :private_key_iv, presence: true
  validates :private_key_key_id, presence: true

  scope :active, -> { where(archived: false) }
  scope :by_type, ->(type) { where(key_type: type) }
  scope :by_fingerprint, ->(fp) { where(fingerprint: fp) }

  # Create with encrypted private key (and optional passphrase)
  def self.create_encrypted(project:, name:, key_type:, public_key:, private_key:, fingerprint:, key_bits: nil, passphrase: nil, comment: nil, metadata: {})
    # Encrypt private key
    encrypted_private = Encryption::Encryptor.encrypt(private_key, project_id: project.id)

    attrs = {
      project: project,
      name: name,
      key_type: key_type,
      public_key: public_key,
      fingerprint: fingerprint,
      key_bits: key_bits,
      encrypted_private_key: encrypted_private.ciphertext,
      private_key_iv: encrypted_private.iv,
      private_key_key_id: encrypted_private.key_id,
      comment: comment,
      metadata: metadata
    }

    # Encrypt passphrase if provided
    if passphrase.present?
      encrypted_pass = Encryption::Encryptor.encrypt(passphrase, project_id: project.id)
      attrs[:encrypted_passphrase] = encrypted_pass.ciphertext
      attrs[:passphrase_iv] = encrypted_pass.iv
      attrs[:passphrase_key_id] = encrypted_pass.key_id
    end

    create!(attrs)
  end

  # Decrypt private key
  def decrypt_private_key
    Encryption::Encryptor.decrypt(
      encrypted_private_key,
      iv: private_key_iv,
      key_id: private_key_key_id,
      project_id: project_id
    )
  end

  # Decrypt passphrase (returns nil if not set)
  def decrypt_passphrase
    return nil unless encrypted_passphrase.present?

    Encryption::Encryptor.decrypt(
      encrypted_passphrase,
      iv: passphrase_iv,
      key_id: passphrase_key_id,
      project_id: project_id
    )
  end

  # Check if key has a passphrase
  def has_passphrase?
    encrypted_passphrase.present?
  end

  # Archive the key (soft delete)
  def archive!
    update!(archived: true, archived_at: Time.current)
  end

  # Restore archived key
  def restore!
    update!(archived: false, archived_at: nil)
  end

  # Get key info without sensitive data
  def to_summary
    {
      id: id,
      name: name,
      key_type: key_type,
      fingerprint: fingerprint,
      key_bits: key_bits,
      public_key: public_key,
      has_passphrase: has_passphrase?,
      comment: comment,
      created_at: created_at,
      archived: archived
    }
  end
end
