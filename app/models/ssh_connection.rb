class SshConnection < ApplicationRecord
  belongs_to :project
  belongs_to :ssh_client_key, optional: true
  belongs_to :jump_connection, class_name: "SshConnection", optional: true

  has_many :dependent_connections, class_name: "SshConnection", foreign_key: :jump_connection_id, dependent: :nullify

  validates :name, presence: true
  validates :host, presence: true
  validates :port, presence: true, numericality: { only_integer: true, greater_than: 0, less_than: 65536 }
  validates :username, presence: true

  scope :active, -> { where(archived: false) }
  scope :with_jump, -> { where.not(jump_connection_id: nil) }

  # Archive the connection (soft delete)
  def archive!
    update!(archived: true, archived_at: Time.current)
  end

  # Restore archived connection
  def restore!
    update!(archived: false, archived_at: nil)
  end

  # Get full connection details including resolved key
  def to_full_details
    details = {
      id: id,
      name: name,
      host: host,
      port: port,
      username: username,
      description: description,
      options: options,
      metadata: metadata,
      created_at: created_at,
      archived: archived
    }

    if ssh_client_key.present?
      details[:client_key] = {
        id: ssh_client_key.id,
        name: ssh_client_key.name,
        fingerprint: ssh_client_key.fingerprint,
        key_type: ssh_client_key.key_type,
        public_key: ssh_client_key.public_key,
        private_key: ssh_client_key.decrypt_private_key,
        has_passphrase: ssh_client_key.has_passphrase?
      }
      if ssh_client_key.has_passphrase?
        details[:client_key][:passphrase] = ssh_client_key.decrypt_passphrase
      end
    end

    if jump_connection.present?
      details[:jump_connection] = jump_connection.to_summary
    end

    details
  end

  # Get connection summary without sensitive data
  def to_summary
    {
      id: id,
      name: name,
      host: host,
      port: port,
      username: username,
      description: description,
      client_key_name: ssh_client_key&.name,
      client_key_fingerprint: ssh_client_key&.fingerprint,
      jump_connection_name: jump_connection&.name,
      options: options,
      created_at: created_at,
      archived: archived
    }
  end

  # Build SSH config block
  def to_ssh_config
    lines = [
      "Host #{name}",
      "  HostName #{host}",
      "  Port #{port}",
      "  User #{username}"
    ]

    if ssh_client_key.present?
      lines << "  IdentityFile ~/.ssh/#{ssh_client_key.name}"
    end

    if jump_connection.present?
      lines << "  ProxyJump #{jump_connection.name}"
    end

    # Add custom options
    options&.each do |key, value|
      lines << "  #{key} #{value}"
    end

    lines.join("\n")
  end
end
