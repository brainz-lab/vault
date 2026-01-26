class SshServerKey < ApplicationRecord
  belongs_to :project

  validates :hostname, presence: true
  validates :port, presence: true, numericality: { only_integer: true, greater_than: 0, less_than: 65536 }
  validates :key_type, presence: true
  validates :public_key, presence: true
  validates :fingerprint, presence: true

  scope :active, -> { where(archived: false) }
  scope :trusted, -> { where(trusted: true) }
  scope :by_host, ->(host, port = 22) { where(hostname: host, port: port) }
  scope :by_fingerprint, ->(fp) { where(fingerprint: fp) }

  # Archive the key (soft delete)
  def archive!
    update!(archived: true, archived_at: Time.current)
  end

  # Restore archived key
  def restore!
    update!(archived: false, archived_at: nil)
  end

  # Mark as verified
  def mark_verified!
    update!(verified_at: Time.current)
  end

  # Mark as trusted/untrusted
  def trust!
    update!(trusted: true)
  end

  def untrust!
    update!(trusted: false)
  end

  # Format as known_hosts line
  def to_known_hosts_line
    "[#{hostname}]:#{port} #{key_type} #{public_key}"
  end

  # Get key info
  def to_summary
    {
      id: id,
      hostname: hostname,
      port: port,
      key_type: key_type,
      fingerprint: fingerprint,
      public_key: public_key,
      trusted: trusted,
      verified_at: verified_at,
      comment: comment,
      created_at: created_at,
      archived: archived
    }
  end
end
