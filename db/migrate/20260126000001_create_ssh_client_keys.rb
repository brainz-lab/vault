class CreateSshClientKeys < ActiveRecord::Migration[8.0]
  def change
    create_table :ssh_client_keys, id: :uuid do |t|
      t.references :project, type: :uuid, null: false, foreign_key: true

      # Identification
      t.string :name, null: false
      t.string :key_type, null: false  # rsa-2048, rsa-4096, ed25519
      t.string :fingerprint, null: false  # SHA256 fingerprint
      t.integer :key_bits

      # Public key (cleartext for easy retrieval)
      t.text :public_key, null: false

      # Encrypted private key
      t.binary :encrypted_private_key, null: false
      t.binary :private_key_iv, null: false
      t.string :private_key_key_id, null: false

      # Optional encrypted passphrase
      t.binary :encrypted_passphrase
      t.binary :passphrase_iv
      t.string :passphrase_key_id

      # Metadata
      t.string :comment
      t.jsonb :metadata, default: {}

      # Status
      t.boolean :archived, default: false
      t.datetime :archived_at

      t.timestamps

      t.index [ :project_id, :name ], unique: true, where: "archived = false", name: "idx_ssh_client_keys_project_name_active"
      t.index [ :project_id, :fingerprint ], name: "idx_ssh_client_keys_project_fingerprint"
      t.index [ :project_id, :archived ]
    end
  end
end
