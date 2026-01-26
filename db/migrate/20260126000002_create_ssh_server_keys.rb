class CreateSshServerKeys < ActiveRecord::Migration[8.0]
  def change
    create_table :ssh_server_keys, id: :uuid do |t|
      t.references :project, type: :uuid, null: false, foreign_key: true

      # Server identification
      t.string :hostname, null: false
      t.integer :port, default: 22, null: false

      # Key information
      t.string :key_type, null: false  # ssh-rsa, ssh-ed25519, ecdsa-sha2-nistp256, etc.
      t.text :public_key, null: false
      t.string :fingerprint, null: false  # SHA256 fingerprint

      # Trust status
      t.boolean :trusted, default: true
      t.datetime :verified_at

      # Metadata
      t.string :comment
      t.jsonb :metadata, default: {}

      # Status
      t.boolean :archived, default: false
      t.datetime :archived_at

      t.timestamps

      t.index [ :project_id, :hostname, :port, :key_type ], unique: true, where: "archived = false", name: "idx_ssh_server_keys_project_host_type"
      t.index [ :project_id, :fingerprint ], name: "idx_ssh_server_keys_project_fingerprint"
      t.index [ :project_id, :archived ]
    end
  end
end
