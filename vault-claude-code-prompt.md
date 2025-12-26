# Vault - Secrets Management

## Overview

Vault securely stores and manages your application secrets, API keys, credentials, and environment variables. Access secrets via API, SDK, or inject them directly into your deployments.

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                                                                              │
│                                VAULT                                         │
│                     "Secrets, secured"                                       │
│                                                                              │
│   ┌──────────────────────────────────────────────────────────────────────┐   │
│   │                                                                      │   │
│   │     ┌─────────────────────────────────────────────────────────────┐  │   │
│   │     │                     SECRET STORE                            │  │   │
│   │     │                                                             │  │   │
│   │     │  🔑 API Keys          🔐 Database Credentials               │  │   │
│   │     │  ├─ STRIPE_API_KEY    ├─ DATABASE_URL                       │  │   │
│   │     │  ├─ OPENAI_API_KEY    ├─ REDIS_URL                          │  │   │
│   │     │  └─ SENDGRID_KEY      └─ ELASTICSEARCH_URL                  │  │   │
│   │     │                                                             │  │   │
│   │     │  🔒 OAuth Secrets     📧 Service Credentials                │  │   │
│   │     │  ├─ GITHUB_SECRET     ├─ AWS_ACCESS_KEY_ID                  │  │   │
│   │     │  ├─ GOOGLE_SECRET     ├─ AWS_SECRET_ACCESS_KEY              │  │   │
│   │     │  └─ SLACK_SECRET      └─ GCP_SERVICE_ACCOUNT                │  │   │
│   │     │                                                             │  │   │
│   │     └─────────────────────────────────────────────────────────────┘  │   │
│   │                                                                      │   │
│   │     Environments                                                     │   │
│   │     ─────────────                                                    │   │
│   │     ┌────────────┐  ┌────────────┐  ┌────────────┐                  │   │
│   │     │ Production │  │  Staging   │  │Development │                  │   │
│   │     │  42 secrets│  │ 38 secrets │  │ 35 secrets │                  │   │
│   │     │  🔒 Locked │  │  🔓 Open   │  │  🔓 Open   │                  │   │
│   │     └────────────┘  └────────────┘  └────────────┘                  │   │
│   │                                                                      │   │
│   └──────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│   ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        │
│   │  Encrypted  │  │   Version   │  │   Access    │  │    Audit    │        │
│   │   Storage   │  │   History   │  │   Control   │  │     Log     │        │
│   │             │  │             │  │             │  │             │        │
│   │ AES-256-GCM │  │ Full audit  │  │ Role-based  │  │ Who, when,  │        │
│   │ at rest     │  │ trail       │  │ permissions │  │ what        │        │
│   └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘        │
│                                                                              │
│   Features: Encryption at rest • Version history • RBAC • Audit logs •      │
│             Environment separation • Secret rotation • CLI & SDK access     │
│                                                                              │
└──────────────────────────────────────────────────────────────────────────────┘
```

---

## Tech Stack

| Component | Technology | Purpose |
|-----------|------------|---------|
| **API** | Rails 8 API | Secret management |
| **Encryption** | AES-256-GCM | Encrypt secrets at rest |
| **Key Management** | AWS KMS / Local | Master key management |
| **Database** | PostgreSQL | Encrypted secret storage |
| **Cache** | Redis | Session & rate limiting |
| **Audit** | Append-only log | Access audit trail |

---

## Directory Structure

```
vault/
├── README.md
├── Dockerfile
├── docker-compose.yml
├── .env.example
│
├── config/
│   ├── routes.rb
│   ├── database.yml
│   └── initializers/
│       ├── encryption.rb
│       └── kms.rb
│
├── app/
│   ├── controllers/
│   │   ├── api/v1/
│   │   │   ├── secrets_controller.rb
│   │   │   ├── environments_controller.rb
│   │   │   ├── versions_controller.rb
│   │   │   ├── access_tokens_controller.rb
│   │   │   ├── audit_logs_controller.rb
│   │   │   └── sync_controller.rb
│   │   └── internal/
│   │       └── inject_controller.rb
│   │
│   ├── models/
│   │   ├── secret.rb
│   │   ├── secret_version.rb
│   │   ├── secret_environment.rb
│   │   ├── secret_folder.rb
│   │   ├── access_token.rb
│   │   ├── access_policy.rb
│   │   ├── audit_log.rb
│   │   └── encryption_key.rb
│   │
│   ├── services/
│   │   ├── encryption/
│   │   │   ├── encryptor.rb
│   │   │   ├── key_manager.rb
│   │   │   ├── aws_kms_provider.rb
│   │   │   └── local_key_provider.rb
│   │   ├── secret_resolver.rb
│   │   ├── secret_rotator.rb
│   │   ├── env_file_generator.rb
│   │   ├── secret_importer.rb
│   │   └── access_checker.rb
│   │
│   ├── jobs/
│   │   ├── rotate_secret_job.rb
│   │   ├── cleanup_versions_job.rb
│   │   ├── sync_secrets_job.rb
│   │   └── audit_retention_job.rb
│   │
│   └── policies/
│       ├── secret_policy.rb
│       └── environment_policy.rb
│
├── lib/
│   └── vault/
│       ├── mcp/
│       │   ├── server.rb
│       │   └── tools/
│       │       ├── list_secrets.rb
│       │       ├── get_secret.rb
│       │       ├── set_secret.rb
│       │       ├── delete_secret.rb
│       │       └── list_environments.rb
│       └── cli/
│           └── commands.rb
│
└── spec/
    ├── models/
    ├── services/
    └── requests/
```

---

## Database Schema

```ruby
# db/migrate/001_create_secret_environments.rb

class CreateSecretEnvironments < ActiveRecord::Migration[8.0]
  def change
    create_table :secret_environments, id: :uuid do |t|
      t.references :platform_project, type: :uuid, null: false
      
      t.string :name, null: false                # production, staging, development
      t.string :slug, null: false                # URL-safe identifier
      t.text :description
      
      # Protection
      t.boolean :protected, default: false       # Require approval for changes
      t.boolean :locked, default: false          # No changes allowed
      
      # Inheritance
      t.references :parent_environment, type: :uuid, foreign_key: { to_table: :secret_environments }
      
      # Settings
      t.string :color                            # For UI display
      t.integer :position, default: 0            # Sort order
      
      t.timestamps
      
      t.index [:platform_project_id, :slug], unique: true
      t.index [:platform_project_id, :name], unique: true
    end
  end
end

# db/migrate/002_create_secret_folders.rb

class CreateSecretFolders < ActiveRecord::Migration[8.0]
  def change
    create_table :secret_folders, id: :uuid do |t|
      t.references :platform_project, type: :uuid, null: false
      
      t.string :name, null: false                # "Database", "API Keys", "OAuth"
      t.string :path, null: false                # "/database", "/api-keys/stripe"
      t.text :description
      
      t.references :parent_folder, type: :uuid, foreign_key: { to_table: :secret_folders }
      
      t.timestamps
      
      t.index [:platform_project_id, :path], unique: true
    end
  end
end

# db/migrate/003_create_secrets.rb

class CreateSecrets < ActiveRecord::Migration[8.0]
  def change
    create_table :secrets, id: :uuid do |t|
      t.references :platform_project, type: :uuid, null: false
      t.references :secret_folder, type: :uuid, foreign_key: true
      
      # Identification
      t.string :key, null: false                 # DATABASE_URL, STRIPE_API_KEY
      t.string :path, null: false                # Full path including folder
      t.text :description
      
      # Metadata
      t.string :secret_type, default: 'string'   # string, json, file, certificate
      t.jsonb :tags, default: {}
      
      # Rotation
      t.boolean :rotation_enabled, default: false
      t.integer :rotation_interval_days
      t.datetime :next_rotation_at
      t.datetime :last_rotated_at
      
      # Status
      t.boolean :archived, default: false
      t.datetime :archived_at
      
      t.timestamps
      
      t.index [:platform_project_id, :path], unique: true
      t.index [:platform_project_id, :key]
      t.index [:platform_project_id, :archived]
    end
  end
end

# db/migrate/004_create_secret_versions.rb

class CreateSecretVersions < ActiveRecord::Migration[8.0]
  def change
    create_table :secret_versions, id: :uuid do |t|
      t.references :secret, type: :uuid, null: false, foreign_key: true
      t.references :secret_environment, type: :uuid, null: false, foreign_key: true
      
      # Version info
      t.integer :version, null: false            # Auto-incrementing per secret+env
      t.boolean :current, default: true          # Is this the active version?
      
      # Encrypted value
      t.binary :encrypted_value, null: false     # AES-256-GCM encrypted
      t.binary :encryption_iv, null: false       # Initialization vector
      t.string :encryption_key_id                # Reference to encryption key
      
      # Value metadata (not encrypted)
      t.integer :value_length                    # Original value length
      t.string :value_hash                       # SHA-256 of original (for comparison)
      
      # Audit
      t.string :created_by                       # User who created this version
      t.text :change_note                        # Optional note about the change
      
      # Expiration
      t.datetime :expires_at                     # Optional expiration
      
      t.datetime :created_at, null: false
      
      t.index [:secret_id, :secret_environment_id, :version], unique: true
      t.index [:secret_id, :secret_environment_id, :current]
      t.index :expires_at
    end
  end
end

# db/migrate/005_create_access_tokens.rb

class CreateAccessTokens < ActiveRecord::Migration[8.0]
  def change
    create_table :access_tokens, id: :uuid do |t|
      t.references :platform_project, type: :uuid, null: false
      
      t.string :name, null: false                # "Production Deploy", "CI/CD"
      t.string :token_digest, null: false        # Hashed token
      t.string :token_prefix, null: false        # First 8 chars for identification
      
      # Scope
      t.string :environments, array: true, default: []  # Empty = all
      t.string :paths, array: true, default: []         # Empty = all (glob patterns)
      t.string :permissions, array: true, default: ['read']  # read, write, delete
      
      # Restrictions
      t.string :allowed_ips, array: true, default: []   # IP allowlist
      t.datetime :expires_at
      
      # Usage tracking
      t.datetime :last_used_at
      t.integer :use_count, default: 0
      
      # Status
      t.boolean :active, default: true
      t.datetime :revoked_at
      t.string :revoked_by
      
      t.timestamps
      
      t.index [:platform_project_id, :token_digest], unique: true
      t.index [:platform_project_id, :active]
    end
  end
end

# db/migrate/006_create_access_policies.rb

class CreateAccessPolicies < ActiveRecord::Migration[8.0]
  def change
    create_table :access_policies, id: :uuid do |t|
      t.references :platform_project, type: :uuid, null: false
      
      t.string :name, null: false
      t.text :description
      
      # Who this policy applies to
      t.string :principal_type, null: false      # user, team, token
      t.string :principal_id                     # User ID, Team ID, or Token ID
      
      # What they can access
      t.string :environments, array: true, default: []
      t.string :paths, array: true, default: []  # Glob patterns: "/database/*"
      
      # What they can do
      t.string :permissions, array: true, default: []
      # read - View secret values
      # write - Create/update secrets
      # delete - Delete secrets
      # admin - Manage access policies
      
      # Conditions
      t.jsonb :conditions, default: {}
      # {
      #   require_mfa: true,
      #   allowed_ips: ["10.0.0.0/8"],
      #   time_window: { start: "09:00", end: "18:00", timezone: "UTC" }
      # }
      
      t.boolean :enabled, default: true
      
      t.timestamps
      
      t.index [:platform_project_id, :principal_type, :principal_id]
    end
  end
end

# db/migrate/007_create_audit_logs.rb

class CreateAuditLogs < ActiveRecord::Migration[8.0]
  def change
    create_table :audit_logs, id: :uuid do |t|
      t.references :platform_project, type: :uuid, null: false
      
      # What happened
      t.string :action, null: false              # read, create, update, delete, rotate
      t.string :resource_type, null: false       # secret, environment, token, policy
      t.uuid :resource_id
      t.string :resource_path                    # Full path for secrets
      
      # Who did it
      t.string :actor_type, null: false          # user, token, system
      t.string :actor_id
      t.string :actor_name                       # For display
      
      # Context
      t.string :ip_address
      t.string :user_agent
      t.string :request_id
      
      # Environment
      t.string :environment                      # Which environment was accessed
      
      # Details
      t.jsonb :metadata, default: {}
      # {
      #   version: 5,
      #   previous_version: 4,
      #   change_note: "Updated for new API version"
      # }
      
      # Result
      t.boolean :success, default: true
      t.text :error_message
      
      t.datetime :created_at, null: false
      
      t.index [:platform_project_id, :created_at]
      t.index [:platform_project_id, :resource_type, :resource_id]
      t.index [:platform_project_id, :actor_type, :actor_id]
      t.index [:platform_project_id, :action]
    end
    
    # Make it append-only (no updates/deletes)
    execute <<-SQL
      CREATE RULE audit_logs_no_update AS ON UPDATE TO audit_logs DO INSTEAD NOTHING;
      CREATE RULE audit_logs_no_delete AS ON DELETE TO audit_logs DO INSTEAD NOTHING;
    SQL
  end
end

# db/migrate/008_create_encryption_keys.rb

class CreateEncryptionKeys < ActiveRecord::Migration[8.0]
  def change
    create_table :encryption_keys, id: :uuid do |t|
      t.references :platform_project, type: :uuid, null: false
      
      t.string :key_id, null: false              # Unique identifier
      t.string :key_type, null: false            # aes-256-gcm
      
      # Key storage (encrypted with master key)
      t.binary :encrypted_key, null: false
      t.binary :encryption_iv, null: false
      
      # KMS reference (if using external KMS)
      t.string :kms_key_arn                      # AWS KMS ARN
      t.string :kms_provider                     # aws, gcp, local
      
      # Status
      t.string :status, default: 'active'        # active, rotating, retired
      t.datetime :activated_at
      t.datetime :retired_at
      
      # Rotation
      t.references :previous_key, type: :uuid, foreign_key: { to_table: :encryption_keys }
      
      t.timestamps
      
      t.index [:platform_project_id, :key_id], unique: true
      t.index [:platform_project_id, :status]
    end
  end
end

# db/migrate/009_create_secret_references.rb

class CreateSecretReferences < ActiveRecord::Migration[8.0]
  def change
    create_table :secret_references, id: :uuid do |t|
      t.references :secret, type: :uuid, null: false, foreign_key: true
      
      # What references this secret
      t.string :reference_type, null: false      # secret, service, deployment
      t.uuid :reference_id
      t.string :reference_path                   # e.g., another secret's path
      
      # How it's referenced
      t.string :reference_kind                   # value, template
      # template example: "postgres://user:${DB_PASSWORD}@host/db"
      
      t.timestamps
      
      t.index [:secret_id, :reference_type, :reference_id], unique: true
    end
  end
end
```

---

## Models

```ruby
# app/models/secret.rb

class Secret < ApplicationRecord
  belongs_to :platform_project, class_name: 'Platform::Project'
  belongs_to :secret_folder, optional: true
  
  has_many :versions, class_name: 'SecretVersion', dependent: :destroy
  has_many :references, class_name: 'SecretReference', dependent: :destroy
  
  validates :key, presence: true, format: { 
    with: /\A[A-Z][A-Z0-9_]*\z/, 
    message: 'must be uppercase with underscores (e.g., DATABASE_URL)' 
  }
  validates :path, presence: true, uniqueness: { scope: :platform_project_id }
  
  before_validation :set_path
  
  scope :active, -> { where(archived: false) }
  scope :in_folder, ->(folder) { where(secret_folder: folder) }
  scope :with_tag, ->(key, value) { where("tags->>? = ?", key, value) }
  
  def current_version(environment)
    versions.where(secret_environment: environment, current: true).first
  end
  
  def value(environment)
    version = current_version(environment)
    return nil unless version
    
    version.decrypt
  end
  
  def set_value(environment, value, user: nil, note: nil)
    ActiveRecord::Base.transaction do
      # Mark previous version as not current
      versions.where(secret_environment: environment, current: true)
              .update_all(current: false)
      
      # Create new version
      version_number = versions.where(secret_environment: environment).maximum(:version).to_i + 1
      
      versions.create!(
        secret_environment: environment,
        version: version_number,
        current: true,
        encrypted_value: Encryption::Encryptor.encrypt(value),
        encryption_iv: Encryption::Encryptor.generate_iv,
        value_length: value.length,
        value_hash: Digest::SHA256.hexdigest(value),
        created_by: user,
        change_note: note
      )
    end
  end
  
  def version_history(environment, limit: 10)
    versions.where(secret_environment: environment)
            .order(version: :desc)
            .limit(limit)
  end
  
  def rollback(environment, to_version:, user: nil)
    target = versions.find_by!(secret_environment: environment, version: to_version)
    
    ActiveRecord::Base.transaction do
      versions.where(secret_environment: environment, current: true)
              .update_all(current: false)
      
      new_version = versions.create!(
        secret_environment: environment,
        version: versions.where(secret_environment: environment).maximum(:version) + 1,
        current: true,
        encrypted_value: target.encrypted_value,
        encryption_iv: target.encryption_iv,
        encryption_key_id: target.encryption_key_id,
        value_length: target.value_length,
        value_hash: target.value_hash,
        created_by: user,
        change_note: "Rollback to version #{to_version}"
      )
      
      new_version
    end
  end
  
  def archive!(user: nil)
    update!(archived: true, archived_at: Time.current)
    
    AuditLog.create!(
      platform_project: platform_project,
      action: 'archive',
      resource_type: 'secret',
      resource_id: id,
      resource_path: path,
      actor_type: user ? 'user' : 'system',
      actor_id: user&.id,
      actor_name: user&.email || 'system'
    )
  end
  
  private
  
  def set_path
    folder_path = secret_folder&.path || ''
    self.path = "#{folder_path}/#{key}".gsub(/^\/+/, '/')
  end
end

# app/models/secret_version.rb

class SecretVersion < ApplicationRecord
  belongs_to :secret
  belongs_to :secret_environment
  
  validates :version, presence: true, numericality: { greater_than: 0 }
  validates :encrypted_value, presence: true
  validates :encryption_iv, presence: true
  
  after_create :audit_creation
  
  def decrypt
    Encryption::Encryptor.decrypt(
      encrypted_value,
      iv: encryption_iv,
      key_id: encryption_key_id
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
      '••••••••'
    end
  end
  
  private
  
  def audit_creation
    AuditLog.create!(
      platform_project: secret.platform_project,
      action: version == 1 ? 'create' : 'update',
      resource_type: 'secret',
      resource_id: secret.id,
      resource_path: secret.path,
      environment: secret_environment.name,
      actor_type: created_by.present? ? 'user' : 'system',
      actor_id: created_by,
      metadata: {
        version: version,
        previous_version: version > 1 ? version - 1 : nil,
        change_note: change_note
      }
    )
  end
end

# app/models/secret_environment.rb

class SecretEnvironment < ApplicationRecord
  belongs_to :platform_project, class_name: 'Platform::Project'
  belongs_to :parent_environment, class_name: 'SecretEnvironment', optional: true
  
  has_many :secret_versions, dependent: :destroy
  has_many :child_environments, class_name: 'SecretEnvironment', foreign_key: :parent_environment_id
  
  validates :name, presence: true, uniqueness: { scope: :platform_project_id }
  validates :slug, presence: true, uniqueness: { scope: :platform_project_id },
                   format: { with: /\A[a-z0-9\-]+\z/ }
  
  before_validation :set_slug
  
  scope :ordered, -> { order(position: :asc) }
  
  def secrets_count
    SecretVersion.joins(:secret)
                 .where(secret_environment: self, current: true)
                 .where(secrets: { platform_project_id: platform_project_id, archived: false })
                 .count
  end
  
  def resolve_value(secret)
    # Check this environment first
    version = secret.current_version(self)
    return version.decrypt if version
    
    # Fall back to parent environment
    if parent_environment
      parent_environment.resolve_value(secret)
    else
      nil
    end
  end
  
  def all_secrets
    Secret.where(platform_project_id: platform_project_id, archived: false)
          .includes(:versions)
          .where(secret_versions: { secret_environment_id: id, current: true })
  end
  
  def export_env_file
    EnvFileGenerator.new(self).generate
  end
  
  private
  
  def set_slug
    self.slug ||= name&.parameterize
  end
end

# app/models/access_token.rb

class AccessToken < ApplicationRecord
  belongs_to :platform_project, class_name: 'Platform::Project'
  
  validates :name, presence: true
  validates :token_digest, presence: true, uniqueness: { scope: :platform_project_id }
  
  before_validation :generate_token, on: :create
  
  attr_accessor :plain_token  # Only available on create
  
  scope :active, -> { where(active: true, revoked_at: nil).where('expires_at IS NULL OR expires_at > ?', Time.current) }
  
  def self.authenticate(token)
    return nil unless token.present?
    
    prefix = token[0..7]
    digest = Digest::SHA256.hexdigest(token)
    
    find_by(token_prefix: prefix, token_digest: digest, active: true)
      &.tap { |t| t.update_columns(last_used_at: Time.current, use_count: t.use_count + 1) }
  end
  
  def can_access?(secret, environment, permission: 'read')
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
  
  private
  
  def generate_token
    self.plain_token = SecureRandom.urlsafe_base64(32)
    self.token_prefix = plain_token[0..7]
    self.token_digest = Digest::SHA256.hexdigest(plain_token)
  end
end

# app/models/audit_log.rb

class AuditLog < ApplicationRecord
  belongs_to :platform_project, class_name: 'Platform::Project'
  
  validates :action, presence: true
  validates :resource_type, presence: true
  validates :actor_type, presence: true
  
  scope :recent, -> { order(created_at: :desc) }
  scope :for_secret, ->(secret) { where(resource_type: 'secret', resource_id: secret.id) }
  scope :by_actor, ->(type, id) { where(actor_type: type, actor_id: id) }
  scope :for_environment, ->(env) { where(environment: env) }
  
  ACTIONS = %w[read create update delete archive rotate rollback access_granted access_denied].freeze
  
  def self.log_access(secret, environment, token:, ip:, success: true, error: nil)
    create!(
      platform_project: secret.platform_project,
      action: success ? 'read' : 'access_denied',
      resource_type: 'secret',
      resource_id: secret.id,
      resource_path: secret.path,
      environment: environment.name,
      actor_type: 'token',
      actor_id: token.id,
      actor_name: token.name,
      ip_address: ip,
      success: success,
      error_message: error
    )
  end
end
```

---

## Encryption Services

```ruby
# app/services/encryption/encryptor.rb

module Encryption
  class Encryptor
    ALGORITHM = 'aes-256-gcm'
    
    class << self
      def encrypt(plaintext, key_id: nil)
        key = KeyManager.current_key(key_id)
        
        cipher = OpenSSL::Cipher.new(ALGORITHM)
        cipher.encrypt
        cipher.key = key.raw_key
        
        iv = cipher.random_iv
        cipher.iv = iv
        cipher.auth_data = ''
        
        encrypted = cipher.update(plaintext) + cipher.final
        auth_tag = cipher.auth_tag
        
        EncryptedData.new(
          ciphertext: encrypted + auth_tag,
          iv: iv,
          key_id: key.key_id
        )
      end
      
      def decrypt(ciphertext, iv:, key_id:)
        key = KeyManager.get_key(key_id)
        
        cipher = OpenSSL::Cipher.new(ALGORITHM)
        cipher.decrypt
        cipher.key = key.raw_key
        cipher.iv = iv
        cipher.auth_data = ''
        
        # Extract auth tag (last 16 bytes)
        auth_tag = ciphertext[-16..]
        encrypted = ciphertext[0..-17]
        
        cipher.auth_tag = auth_tag
        cipher.update(encrypted) + cipher.final
      end
      
      def generate_iv
        OpenSSL::Cipher.new(ALGORITHM).random_iv
      end
    end
    
    EncryptedData = Struct.new(:ciphertext, :iv, :key_id, keyword_init: true)
  end
end

# app/services/encryption/key_manager.rb

module Encryption
  class KeyManager
    class << self
      def current_key(project_id = nil)
        # Get the active key for the project
        key_record = EncryptionKey.where(status: 'active')
        key_record = key_record.where(platform_project_id: project_id) if project_id
        key_record = key_record.order(created_at: :desc).first
        
        key_record || create_key(project_id)
      end
      
      def get_key(key_id)
        key_record = EncryptionKey.find_by!(key_id: key_id)
        decrypt_key(key_record)
      end
      
      def create_key(project_id)
        raw_key = OpenSSL::Random.random_bytes(32)  # 256 bits
        
        # Encrypt with master key
        encrypted = master_key_provider.encrypt(raw_key)
        
        key_record = EncryptionKey.create!(
          platform_project_id: project_id,
          key_id: SecureRandom.uuid,
          key_type: 'aes-256-gcm',
          encrypted_key: encrypted[:ciphertext],
          encryption_iv: encrypted[:iv],
          kms_provider: master_key_provider.provider_name,
          status: 'active',
          activated_at: Time.current
        )
        
        KeyWrapper.new(key_record, raw_key)
      end
      
      def rotate_key(project_id)
        old_key = current_key(project_id)
        new_key = create_key(project_id)
        
        # Mark old key as rotating
        old_key.record.update!(status: 'rotating')
        
        # Re-encrypt all secrets with new key
        SecretVersion.joins(:secret)
                     .where(secrets: { platform_project_id: project_id })
                     .where(encryption_key_id: old_key.key_id)
                     .find_each do |version|
          
          # Decrypt with old key, encrypt with new key
          plaintext = Encryptor.decrypt(
            version.encrypted_value,
            iv: version.encryption_iv,
            key_id: old_key.key_id
          )
          
          encrypted = Encryptor.encrypt(plaintext, key_id: new_key.key_id)
          
          version.update!(
            encrypted_value: encrypted.ciphertext,
            encryption_iv: encrypted.iv,
            encryption_key_id: encrypted.key_id
          )
        end
        
        # Retire old key
        old_key.record.update!(status: 'retired', retired_at: Time.current)
        
        new_key
      end
      
      private
      
      def master_key_provider
        @master_key_provider ||= begin
          if ENV['AWS_KMS_KEY_ARN'].present?
            AwsKmsProvider.new
          else
            LocalKeyProvider.new
          end
        end
      end
      
      def decrypt_key(key_record)
        raw_key = master_key_provider.decrypt(
          key_record.encrypted_key,
          iv: key_record.encryption_iv
        )
        
        KeyWrapper.new(key_record, raw_key)
      end
    end
    
    KeyWrapper = Struct.new(:record, :raw_key) do
      def key_id
        record.key_id
      end
    end
  end
end

# app/services/encryption/aws_kms_provider.rb

module Encryption
  class AwsKmsProvider
    def initialize
      @client = Aws::KMS::Client.new
      @key_arn = ENV.fetch('AWS_KMS_KEY_ARN')
    end
    
    def provider_name
      'aws'
    end
    
    def encrypt(plaintext)
      response = @client.encrypt(
        key_id: @key_arn,
        plaintext: plaintext
      )
      
      {
        ciphertext: response.ciphertext_blob,
        iv: nil  # KMS handles IV internally
      }
    end
    
    def decrypt(ciphertext, iv: nil)
      response = @client.decrypt(
        key_id: @key_arn,
        ciphertext_blob: ciphertext
      )
      
      response.plaintext
    end
  end
end

# app/services/encryption/local_key_provider.rb

module Encryption
  class LocalKeyProvider
    ALGORITHM = 'aes-256-gcm'
    
    def initialize
      @master_key = derive_master_key
    end
    
    def provider_name
      'local'
    end
    
    def encrypt(plaintext)
      cipher = OpenSSL::Cipher.new(ALGORITHM)
      cipher.encrypt
      cipher.key = @master_key
      
      iv = cipher.random_iv
      cipher.iv = iv
      cipher.auth_data = ''
      
      encrypted = cipher.update(plaintext) + cipher.final
      auth_tag = cipher.auth_tag
      
      {
        ciphertext: encrypted + auth_tag,
        iv: iv
      }
    end
    
    def decrypt(ciphertext, iv:)
      cipher = OpenSSL::Cipher.new(ALGORITHM)
      cipher.decrypt
      cipher.key = @master_key
      cipher.iv = iv
      cipher.auth_data = ''
      
      auth_tag = ciphertext[-16..]
      encrypted = ciphertext[0..-17]
      
      cipher.auth_tag = auth_tag
      cipher.update(encrypted) + cipher.final
    end
    
    private
    
    def derive_master_key
      master_key_base = ENV.fetch('VAULT_MASTER_KEY') do
        raise 'VAULT_MASTER_KEY environment variable must be set'
      end
      
      # Use PBKDF2 to derive a key from the master key
      OpenSSL::PKCS5.pbkdf2_hmac(
        master_key_base,
        'vault-key-derivation-salt',
        100_000,
        32,
        OpenSSL::Digest::SHA256.new
      )
    end
  end
end
```

---

## Services

```ruby
# app/services/secret_resolver.rb

class SecretResolver
  def initialize(project, environment)
    @project = project
    @environment = environment
  end
  
  def resolve(path)
    secret = @project.secrets.active.find_by(path: path)
    return nil unless secret
    
    @environment.resolve_value(secret)
  end
  
  def resolve_all
    secrets = {}
    
    @project.secrets.active.find_each do |secret|
      value = @environment.resolve_value(secret)
      secrets[secret.key] = value if value.present?
    end
    
    secrets
  end
  
  def resolve_with_references(template)
    # Replace ${SECRET_NAME} with actual values
    template.gsub(/\$\{([A-Z_][A-Z0-9_]*)\}/) do |match|
      key = $1
      secret = @project.secrets.active.find_by(key: key)
      secret ? @environment.resolve_value(secret) : match
    end
  end
  
  def resolve_for_service(service_name)
    # Get secrets tagged for this service
    @project.secrets
            .active
            .with_tag('service', service_name)
            .each_with_object({}) do |secret, hash|
      value = @environment.resolve_value(secret)
      hash[secret.key] = value if value.present?
    end
  end
end

# app/services/env_file_generator.rb

class EnvFileGenerator
  def initialize(environment)
    @environment = environment
    @project = environment.platform_project
  end
  
  def generate(format: :dotenv)
    secrets = SecretResolver.new(@project, @environment).resolve_all
    
    case format
    when :dotenv
      generate_dotenv(secrets)
    when :json
      secrets.to_json
    when :yaml
      secrets.to_yaml
    when :shell
      generate_shell(secrets)
    else
      raise ArgumentError, "Unknown format: #{format}"
    end
  end
  
  private
  
  def generate_dotenv(secrets)
    secrets.map do |key, value|
      escaped_value = value.gsub('"', '\\"').gsub("\n", '\\n')
      "#{key}=\"#{escaped_value}\""
    end.join("\n")
  end
  
  def generate_shell(secrets)
    secrets.map do |key, value|
      escaped_value = Shellwords.escape(value)
      "export #{key}=#{escaped_value}"
    end.join("\n")
  end
end

# app/services/secret_importer.rb

class SecretImporter
  def initialize(project, environment)
    @project = project
    @environment = environment
  end
  
  def import_from_env_file(content, user: nil)
    imported = []
    errors = []
    
    content.each_line do |line|
      line = line.strip
      next if line.empty? || line.start_with?('#')
      
      if match = line.match(/\A([A-Z][A-Z0-9_]*)=(.*)?\z/)
        key = match[1]
        value = parse_value(match[2])
        
        begin
          import_secret(key, value, user: user)
          imported << key
        rescue => e
          errors << { key: key, error: e.message }
        end
      end
    end
    
    { imported: imported, errors: errors }
  end
  
  def import_from_json(json_content, user: nil)
    data = JSON.parse(json_content)
    imported = []
    errors = []
    
    data.each do |key, value|
      begin
        import_secret(key.upcase, value.to_s, user: user)
        imported << key
      rescue => e
        errors << { key: key, error: e.message }
      end
    end
    
    { imported: imported, errors: errors }
  end
  
  private
  
  def import_secret(key, value, user: nil)
    secret = @project.secrets.find_or_initialize_by(key: key)
    
    if secret.new_record?
      secret.save!
    end
    
    secret.set_value(@environment, value, user: user, note: 'Imported')
  end
  
  def parse_value(raw_value)
    return '' if raw_value.nil?
    
    # Remove surrounding quotes
    if raw_value.start_with?('"') && raw_value.end_with?('"')
      raw_value[1..-2].gsub('\\n', "\n").gsub('\\"', '"')
    elsif raw_value.start_with?("'") && raw_value.end_with?("'")
      raw_value[1..-2]
    else
      raw_value
    end
  end
end

# app/services/access_checker.rb

class AccessChecker
  def initialize(project)
    @project = project
  end
  
  def can_access?(principal, secret, environment, permission: 'read')
    policies = find_policies(principal)
    
    policies.any? do |policy|
      policy_matches?(policy, secret, environment, permission)
    end
  end
  
  def check_conditions(policy, context)
    conditions = policy.conditions
    
    # Check MFA requirement
    if conditions['require_mfa']
      return false unless context[:mfa_verified]
    end
    
    # Check IP allowlist
    if conditions['allowed_ips'].present?
      return false unless ip_allowed?(context[:ip], conditions['allowed_ips'])
    end
    
    # Check time window
    if conditions['time_window'].present?
      return false unless in_time_window?(conditions['time_window'])
    end
    
    true
  end
  
  private
  
  def find_policies(principal)
    type, id = case principal
               when User then ['user', principal.id]
               when AccessToken then ['token', principal.id]
               when Team then ['team', principal.id]
               end
    
    AccessPolicy.where(platform_project: @project, enabled: true)
                .where(principal_type: type, principal_id: id)
  end
  
  def policy_matches?(policy, secret, environment, permission)
    # Check environment
    if policy.environments.any?
      return false unless policy.environments.include?(environment.slug)
    end
    
    # Check path
    if policy.paths.any?
      return false unless policy.paths.any? { |p| File.fnmatch?(p, secret.path) }
    end
    
    # Check permission
    policy.permissions.include?(permission)
  end
  
  def ip_allowed?(ip, allowed_ips)
    allowed_ips.any? do |allowed|
      if allowed.include?('/')
        IPAddr.new(allowed).include?(ip)
      else
        allowed == ip
      end
    end
  end
  
  def in_time_window?(window)
    tz = ActiveSupport::TimeZone[window['timezone'] || 'UTC']
    now = Time.current.in_time_zone(tz)
    
    start_time = Time.parse(window['start'])
    end_time = Time.parse(window['end'])
    
    now.strftime('%H:%M') >= window['start'] && now.strftime('%H:%M') <= window['end']
  end
end
```

---

## Controllers

```ruby
# app/controllers/api/v1/secrets_controller.rb

module Api
  module V1
    class SecretsController < BaseController
      before_action :set_environment
      before_action :set_secret, only: [:show, :update, :destroy, :history, :rollback]
      
      # GET /api/v1/environments/:env/secrets
      def index
        secrets = current_project.secrets.active
        
        if params[:folder].present?
          folder = current_project.secret_folders.find_by!(path: params[:folder])
          secrets = secrets.in_folder(folder)
        end
        
        if params[:tag].present?
          key, value = params[:tag].split(':')
          secrets = secrets.with_tag(key, value)
        end
        
        render json: secrets.map { |s| serialize_secret(s) }
      end
      
      # GET /api/v1/environments/:env/secrets/:path
      def show
        authorize_access!(@secret, 'read')
        
        log_access(@secret, success: true)
        
        render json: serialize_secret(@secret, include_value: true)
      end
      
      # POST /api/v1/environments/:env/secrets
      def create
        @secret = current_project.secrets.find_or_initialize_by(key: secret_params[:key])
        
        authorize_access!(@secret, 'write')
        
        @secret.assign_attributes(secret_params.except(:value))
        @secret.save!
        
        if params[:value].present?
          @secret.set_value(@environment, params[:value], user: current_user_id, note: params[:note])
        end
        
        render json: serialize_secret(@secret), status: :created
      end
      
      # PATCH /api/v1/environments/:env/secrets/:path
      def update
        authorize_access!(@secret, 'write')
        
        if params[:value].present?
          @secret.set_value(@environment, params[:value], user: current_user_id, note: params[:note])
        end
        
        @secret.update!(secret_params.except(:value, :key))
        
        render json: serialize_secret(@secret)
      end
      
      # DELETE /api/v1/environments/:env/secrets/:path
      def destroy
        authorize_access!(@secret, 'delete')
        
        @secret.archive!(user: current_user_id)
        
        head :no_content
      end
      
      # GET /api/v1/environments/:env/secrets/:path/history
      def history
        authorize_access!(@secret, 'read')
        
        versions = @secret.version_history(@environment, limit: params[:limit] || 20)
        
        render json: versions.map { |v| serialize_version(v) }
      end
      
      # POST /api/v1/environments/:env/secrets/:path/rollback
      def rollback
        authorize_access!(@secret, 'write')
        
        version = @secret.rollback(
          @environment,
          to_version: params[:version].to_i,
          user: current_user_id
        )
        
        render json: serialize_version(version)
      end
      
      private
      
      def set_environment
        @environment = current_project.secret_environments.find_by!(slug: params[:environment_id])
      end
      
      def set_secret
        path = "/#{params[:path]}"
        @secret = current_project.secrets.active.find_by!(path: path)
      end
      
      def secret_params
        params.require(:secret).permit(:key, :description, :secret_type, :secret_folder_id, tags: {})
      end
      
      def authorize_access!(secret, permission)
        unless access_checker.can_access?(current_principal, secret, @environment, permission: permission)
          log_access(secret, success: false, error: 'Access denied')
          raise Forbidden, 'Access denied'
        end
      end
      
      def access_checker
        @access_checker ||= AccessChecker.new(current_project)
      end
      
      def log_access(secret, success:, error: nil)
        AuditLog.log_access(
          secret,
          @environment,
          token: current_token,
          ip: request.remote_ip,
          success: success,
          error: error
        )
      end
      
      def serialize_secret(secret, include_value: false)
        data = {
          id: secret.id,
          key: secret.key,
          path: secret.path,
          description: secret.description,
          type: secret.secret_type,
          tags: secret.tags,
          folder: secret.secret_folder&.path,
          created_at: secret.created_at,
          updated_at: secret.updated_at
        }
        
        if include_value
          version = secret.current_version(@environment)
          if version
            data[:value] = version.decrypt
            data[:version] = version.version
            data[:value_updated_at] = version.created_at
          end
        end
        
        data
      end
      
      def serialize_version(version)
        {
          version: version.version,
          current: version.current,
          created_at: version.created_at,
          created_by: version.created_by,
          change_note: version.change_note,
          value_preview: version.value_preview
        }
      end
    end
  end
end

# app/controllers/api/v1/sync_controller.rb

module Api
  module V1
    class SyncController < BaseController
      # GET /api/v1/environments/:env/sync
      def show
        environment = current_project.secret_environments.find_by!(slug: params[:environment_id])
        
        resolver = SecretResolver.new(current_project, environment)
        secrets = resolver.resolve_all
        
        format = params[:format] || 'json'
        
        case format
        when 'dotenv'
          render plain: EnvFileGenerator.new(environment).generate(format: :dotenv),
                 content_type: 'text/plain'
        when 'shell'
          render plain: EnvFileGenerator.new(environment).generate(format: :shell),
                 content_type: 'text/plain'
        when 'yaml'
          render plain: secrets.to_yaml, content_type: 'text/yaml'
        else
          render json: secrets
        end
      end
      
      # POST /api/v1/environments/:env/sync/import
      def import
        environment = current_project.secret_environments.find_by!(slug: params[:environment_id])
        
        importer = SecretImporter.new(current_project, environment)
        
        result = case params[:format]
                 when 'json'
                   importer.import_from_json(params[:content], user: current_user_id)
                 else
                   importer.import_from_env_file(params[:content], user: current_user_id)
                 end
        
        render json: result
      end
    end
  end
end

# app/controllers/internal/inject_controller.rb

module Internal
  class InjectController < ApplicationController
    skip_before_action :verify_authenticity_token
    before_action :authenticate_token
    
    # POST /internal/inject
    # Used by deployment systems to inject secrets
    def create
      environment = @project.secret_environments.find_by!(slug: params[:environment])
      
      resolver = SecretResolver.new(@project, environment)
      
      secrets = if params[:keys].present?
                  # Only specific keys
                  params[:keys].each_with_object({}) do |key, hash|
                    secret = @project.secrets.active.find_by(key: key)
                    if secret && @token.can_access?(secret, environment)
                      hash[key] = resolver.resolve(secret.path)
                    end
                  end
                else
                  # All accessible secrets
                  resolver.resolve_all.select do |key, _|
                    secret = @project.secrets.active.find_by(key: key)
                    secret && @token.can_access?(secret, environment)
                  end
                end
      
      render json: { secrets: secrets, count: secrets.size }
    end
    
    private
    
    def authenticate_token
      token = request.headers['Authorization']&.sub('Bearer ', '')
      @token = AccessToken.authenticate(token)
      
      unless @token
        render json: { error: 'Invalid token' }, status: :unauthorized
        return
      end
      
      @project = @token.platform_project
    end
  end
end
```

---

## MCP Tools

```ruby
# lib/vault/mcp/tools/list_secrets.rb

module Vault
  module Mcp
    module Tools
      class ListSecrets < BaseTool
        TOOL_NAME = 'vault_list_secrets'
        DESCRIPTION = 'List all secrets in a project'
        
        SCHEMA = {
          type: 'object',
          properties: {
            environment: {
              type: 'string',
              description: 'Environment name (production, staging, etc.)'
            },
            folder: {
              type: 'string',
              description: 'Filter by folder path'
            },
            tag: {
              type: 'string',
              description: 'Filter by tag (format: key:value)'
            }
          }
        }.freeze
        
        def call(args)
          secrets = project.secrets.active
          
          if args[:folder]
            folder = project.secret_folders.find_by(path: args[:folder])
            secrets = secrets.in_folder(folder) if folder
          end
          
          if args[:tag]
            key, value = args[:tag].split(':')
            secrets = secrets.with_tag(key, value)
          end
          
          environment = if args[:environment]
                          project.secret_environments.find_by(slug: args[:environment])
                        end
          
          {
            secrets: secrets.map do |s|
              data = {
                key: s.key,
                path: s.path,
                type: s.secret_type,
                description: s.description
              }
              
              if environment
                version = s.current_version(environment)
                data[:has_value] = version.present?
                data[:version] = version&.version
              end
              
              data
            end,
            total: secrets.count
          }
        end
      end
      
      class GetSecret < BaseTool
        TOOL_NAME = 'vault_get_secret'
        DESCRIPTION = 'Get a secret value'
        
        SCHEMA = {
          type: 'object',
          properties: {
            key: {
              type: 'string',
              description: 'Secret key (e.g., DATABASE_URL)'
            },
            environment: {
              type: 'string',
              description: 'Environment name',
              default: 'development'
            }
          },
          required: ['key']
        }.freeze
        
        def call(args)
          secret = project.secrets.active.find_by!(key: args[:key])
          environment = project.secret_environments.find_by!(slug: args[:environment] || 'development')
          
          value = secret.value(environment)
          
          # Mask sensitive parts for display
          masked_value = mask_value(value)
          
          {
            key: secret.key,
            path: secret.path,
            environment: environment.name,
            value: masked_value,
            full_value_available: true,
            version: secret.current_version(environment)&.version,
            note: "Full value retrieved. Showing masked version for safety."
          }
        end
        
        private
        
        def mask_value(value)
          return nil if value.nil?
          return '••••••••' if value.length <= 8
          
          "#{value[0..3]}#{'•' * [value.length - 8, 4].max}#{value[-4..]}"
        end
      end
      
      class SetSecret < BaseTool
        TOOL_NAME = 'vault_set_secret'
        DESCRIPTION = 'Create or update a secret'
        
        SCHEMA = {
          type: 'object',
          properties: {
            key: {
              type: 'string',
              description: 'Secret key (uppercase with underscores)'
            },
            value: {
              type: 'string',
              description: 'Secret value'
            },
            environment: {
              type: 'string',
              description: 'Environment name',
              default: 'development'
            },
            description: {
              type: 'string',
              description: 'Optional description'
            },
            note: {
              type: 'string',
              description: 'Change note for audit'
            }
          },
          required: ['key', 'value']
        }.freeze
        
        def call(args)
          environment = project.secret_environments.find_by!(slug: args[:environment] || 'development')
          
          secret = project.secrets.find_or_initialize_by(key: args[:key].upcase)
          secret.description = args[:description] if args[:description]
          secret.save!
          
          secret.set_value(
            environment,
            args[:value],
            user: 'mcp',
            note: args[:note] || 'Set via MCP'
          )
          
          {
            key: secret.key,
            path: secret.path,
            environment: environment.name,
            version: secret.current_version(environment).version,
            message: secret.previously_new_record? ? 'Secret created' : 'Secret updated'
          }
        end
      end
      
      class DeleteSecret < BaseTool
        TOOL_NAME = 'vault_delete_secret'
        DESCRIPTION = 'Archive (soft-delete) a secret'
        
        SCHEMA = {
          type: 'object',
          properties: {
            key: {
              type: 'string',
              description: 'Secret key to delete'
            },
            confirm: {
              type: 'boolean',
              description: 'Must be true to confirm deletion'
            }
          },
          required: ['key', 'confirm']
        }.freeze
        
        def call(args)
          return { error: 'Must confirm deletion' } unless args[:confirm]
          
          secret = project.secrets.active.find_by!(key: args[:key])
          secret.archive!(user: 'mcp')
          
          {
            key: secret.key,
            archived: true,
            message: 'Secret archived successfully'
          }
        end
      end
      
      class ListEnvironments < BaseTool
        TOOL_NAME = 'vault_list_environments'
        DESCRIPTION = 'List all secret environments'
        
        SCHEMA = {
          type: 'object',
          properties: {}
        }.freeze
        
        def call(args)
          environments = project.secret_environments.ordered
          
          {
            environments: environments.map do |env|
              {
                name: env.name,
                slug: env.slug,
                protected: env.protected,
                locked: env.locked,
                secrets_count: env.secrets_count,
                parent: env.parent_environment&.name
              }
            end
          }
        end
      end
    end
  end
end
```

---

## CLI Tool

```ruby
# lib/vault/cli/commands.rb

module Vault
  module CLI
    class Commands < Thor
      desc "list [ENVIRONMENT]", "List all secrets"
      option :folder, type: :string, desc: "Filter by folder"
      def list(environment = 'development')
        secrets = client.list_secrets(environment: environment, folder: options[:folder])
        
        table = Terminal::Table.new do |t|
          t.headings = ['Key', 'Path', 'Type', 'Has Value']
          secrets[:secrets].each do |s|
            t << [s[:key], s[:path], s[:type], s[:has_value] ? '✓' : '-']
          end
        end
        
        puts table
        puts "\nTotal: #{secrets[:total]} secrets"
      end
      
      desc "get KEY", "Get a secret value"
      option :environment, aliases: '-e', default: 'development'
      option :quiet, aliases: '-q', type: :boolean, desc: "Output only the value"
      def get(key)
        result = client.get_secret(key: key, environment: options[:environment])
        
        if options[:quiet]
          # Get unmasked value for piping
          puts client.get_secret_raw(key: key, environment: options[:environment])
        else
          puts "Key: #{result[:key]}"
          puts "Environment: #{result[:environment]}"
          puts "Value: #{result[:value]}"
          puts "Version: #{result[:version]}"
        end
      end
      
      desc "set KEY VALUE", "Set a secret value"
      option :environment, aliases: '-e', default: 'development'
      option :description, aliases: '-d', type: :string
      option :note, aliases: '-n', type: :string
      def set(key, value = nil)
        # Read from stdin if value not provided
        value ||= $stdin.read.chomp
        
        result = client.set_secret(
          key: key,
          value: value,
          environment: options[:environment],
          description: options[:description],
          note: options[:note]
        )
        
        puts "✓ #{result[:message]}"
        puts "  Path: #{result[:path]}"
        puts "  Version: #{result[:version]}"
      end
      
      desc "delete KEY", "Delete (archive) a secret"
      option :force, aliases: '-f', type: :boolean, desc: "Skip confirmation"
      def delete(key)
        unless options[:force]
          print "Are you sure you want to delete '#{key}'? [y/N] "
          return unless $stdin.gets.chomp.downcase == 'y'
        end
        
        result = client.delete_secret(key: key, confirm: true)
        puts "✓ Secret archived"
      end
      
      desc "sync ENVIRONMENT", "Sync secrets to local .env file"
      option :output, aliases: '-o', default: '.env'
      option :format, aliases: '-f', default: 'dotenv', enum: %w[dotenv json yaml shell]
      def sync(environment)
        content = client.sync(environment: environment, format: options[:format])
        
        File.write(options[:output], content)
        puts "✓ Synced to #{options[:output]}"
      end
      
      desc "import FILE", "Import secrets from .env file"
      option :environment, aliases: '-e', default: 'development'
      option :format, aliases: '-f', default: 'dotenv', enum: %w[dotenv json]
      def import(file)
        content = File.read(file)
        result = client.import(
          environment: options[:environment],
          content: content,
          format: options[:format]
        )
        
        puts "✓ Imported #{result[:imported].size} secrets"
        if result[:errors].any?
          puts "✗ #{result[:errors].size} errors:"
          result[:errors].each { |e| puts "  - #{e[:key]}: #{e[:error]}" }
        end
      end
      
      desc "envs", "List environments"
      def envs
        result = client.list_environments
        
        table = Terminal::Table.new do |t|
          t.headings = ['Name', 'Slug', 'Protected', 'Secrets']
          result[:environments].each do |env|
            t << [env[:name], env[:slug], env[:protected] ? '🔒' : '', env[:secrets_count]]
          end
        end
        
        puts table
      end
      
      desc "history KEY", "Show version history for a secret"
      option :environment, aliases: '-e', default: 'development'
      option :limit, aliases: '-l', type: :numeric, default: 10
      def history(key)
        result = client.history(key: key, environment: options[:environment], limit: options[:limit])
        
        table = Terminal::Table.new do |t|
          t.headings = ['Version', 'Current', 'Created', 'By', 'Note']
          result[:versions].each do |v|
            t << [v[:version], v[:current] ? '→' : '', v[:created_at], v[:created_by], v[:change_note]]
          end
        end
        
        puts table
      end
      
      private
      
      def client
        @client ||= Vault::Client.new(
          api_key: ENV['BRAINZLAB_API_KEY'],
          endpoint: ENV.fetch('VAULT_ENDPOINT', 'https://vault.brainzlab.ai')
        )
      end
    end
  end
end
```

---

## Routes

```ruby
# config/routes.rb

Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      resources :environments, param: :slug do
        resources :secrets, param: :path, path: 'secrets/*path', constraints: { path: /.*/ } do
          member do
            get :history
            post :rollback
          end
        end
        
        resource :sync, only: [:show] do
          post :import
        end
      end
      
      resources :folders, param: :path, path: 'folders/*path', constraints: { path: /.*/ }
      resources :access_tokens
      resources :access_policies
      resources :audit_logs, only: [:index, :show]
    end
  end
  
  # Internal endpoints
  namespace :internal do
    post 'inject', to: 'inject#create'
  end
  
  # Health
  get 'health', to: 'health#show'
end
```

---

## Docker Compose

```yaml
# docker-compose.yml

version: '3.8'

services:
  web:
    build: .
    ports:
      - "3011:3000"
    environment:
      - DATABASE_URL=postgres://postgres:postgres@db:5432/vault
      - REDIS_URL=redis://redis:6379
      - VAULT_MASTER_KEY=${VAULT_MASTER_KEY}
      - RAILS_MASTER_KEY=${RAILS_MASTER_KEY}
    depends_on:
      - db
      - redis
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.vault.rule=Host(`vault.brainzlab.localhost`)"

  worker:
    build: .
    command: bundle exec rake solid_queue:start
    environment:
      - DATABASE_URL=postgres://postgres:postgres@db:5432/vault
      - REDIS_URL=redis://redis:6379
      - VAULT_MASTER_KEY=${VAULT_MASTER_KEY}
    depends_on:
      - db
      - redis

  db:
    image: postgres:16-alpine
    environment:
      - POSTGRES_USER=postgres
      - POSTGRES_PASSWORD=postgres
      - POSTGRES_DB=vault
    volumes:
      - postgres_data:/var/lib/postgresql/data
    ports:
      - "5441:5432"

  redis:
    image: redis:7-alpine
    volumes:
      - redis_data:/data

volumes:
  postgres_data:
  redis_data:
```

---

## SDK Integration

```ruby
# In the main brainzlab gem

module Brainzlab
  class Vault
    def initialize(api_key:, endpoint: 'https://vault.brainzlab.ai')
      @api_key = api_key
      @endpoint = endpoint
      @cache = {}
    end
    
    # Fetch all secrets for an environment
    def fetch_all(environment:)
      response = get("/api/v1/environments/#{environment}/sync")
      JSON.parse(response.body)
    end
    
    # Fetch a single secret
    def fetch(key, environment:)
      response = get("/api/v1/environments/#{environment}/secrets/#{key}")
      data = JSON.parse(response.body)
      data['value']
    end
    
    # Fetch with caching
    def get(key, environment:, ttl: 300)
      cache_key = "#{environment}:#{key}"
      
      if @cache[cache_key] && @cache[cache_key][:expires_at] > Time.now
        return @cache[cache_key][:value]
      end
      
      value = fetch(key, environment: environment)
      @cache[cache_key] = { value: value, expires_at: Time.now + ttl }
      value
    end
    
    # Load secrets into ENV
    def load_env!(environment:, keys: nil)
      secrets = fetch_all(environment: environment)
      
      secrets.each do |key, value|
        next if keys && !keys.include?(key)
        ENV[key] = value
      end
      
      secrets.keys
    end
    
    private
    
    def get(path)
      conn.get(path)
    end
    
    def conn
      @conn ||= Faraday.new(@endpoint) do |f|
        f.headers['Authorization'] = "Bearer #{@api_key}"
        f.headers['Content-Type'] = 'application/json'
      end
    end
  end
end

# Usage in Rails initializer:
# config/initializers/vault.rb

if Rails.env.production?
  vault = Brainzlab::Vault.new(api_key: ENV['BRAINZLAB_API_KEY'])
  vault.load_env!(environment: 'production')
end
```

---

## Summary

### Vault Features

| Feature | Description |
|---------|-------------|
| **Encrypted Storage** | AES-256-GCM encryption at rest |
| **Version History** | Full audit trail of changes |
| **Environments** | Separate secrets per environment |
| **Inheritance** | Fallback to parent environment |
| **Access Control** | Role-based with policies |
| **Audit Logs** | Append-only access logs |
| **CLI Tool** | Full CLI for secret management |
| **Import/Export** | .env, JSON, YAML formats |

### MCP Tools

| Tool | Description |
|------|-------------|
| `vault_list_secrets` | List all secrets |
| `vault_get_secret` | Get secret value |
| `vault_set_secret` | Create/update secret |
| `vault_delete_secret` | Archive a secret |
| `vault_list_environments` | List environments |

### Integration Points

| Product | Integration |
|---------|-------------|
| **Synapse** | Deploy Agent injects secrets |
| **Platform** | Centralized API key management |
| **All Products** | Secure credential storage |

### Security Features

| Feature | Description |
|---------|-------------|
| **Encryption** | AES-256-GCM with per-project keys |
| **Key Management** | AWS KMS or local master key |
| **Key Rotation** | Automatic re-encryption |
| **Access Tokens** | Scoped, expirable tokens |
| **IP Allowlists** | Restrict by IP/CIDR |
| **Audit Trail** | Immutable access logs |

---

*Vault = Secrets, secured! 🔐*
