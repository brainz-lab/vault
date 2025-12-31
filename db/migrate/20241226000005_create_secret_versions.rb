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

      t.index [ :secret_id, :secret_environment_id, :version ], unique: true, name: "idx_secret_versions_unique"
      t.index [ :secret_id, :secret_environment_id, :current ], name: "idx_secret_versions_current"
      t.index :expires_at
    end
  end
end
