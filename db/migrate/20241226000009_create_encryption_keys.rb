class CreateEncryptionKeys < ActiveRecord::Migration[8.0]
  def change
    create_table :encryption_keys, id: :uuid do |t|
      t.references :project, type: :uuid, null: false, foreign_key: true

      t.string :key_id, null: false              # Unique identifier
      t.string :key_type, null: false            # aes-256-gcm

      # Key storage (encrypted with master key)
      t.binary :encrypted_key, null: false
      t.binary :encryption_iv, null: false

      # KMS reference (if using external KMS)
      t.string :kms_key_arn                      # AWS KMS ARN
      t.string :kms_provider                     # aws, gcp, local

      # Status
      t.string :status, default: "active"        # active, rotating, retired
      t.datetime :activated_at
      t.datetime :retired_at

      # Rotation
      t.references :previous_key, type: :uuid, foreign_key: { to_table: :encryption_keys }

      t.timestamps

      t.index [ :project_id, :key_id ], unique: true
      t.index [ :project_id, :status ]
    end
  end
end
