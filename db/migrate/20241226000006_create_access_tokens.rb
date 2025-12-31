class CreateAccessTokens < ActiveRecord::Migration[8.0]
  def change
    create_table :access_tokens, id: :uuid do |t|
      t.references :project, type: :uuid, null: false, foreign_key: true

      t.string :name, null: false                # "Production Deploy", "CI/CD"
      t.string :token_digest, null: false        # Hashed token
      t.string :token_prefix, null: false        # First 8 chars for identification

      # Scope
      t.string :environments, array: true, default: []  # Empty = all
      t.string :paths, array: true, default: []         # Empty = all (glob patterns)
      t.string :permissions, array: true, default: [ "read" ]  # read, write, delete

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

      t.index [ :project_id, :token_digest ], unique: true
      t.index [ :project_id, :active ]
    end
  end
end
