class CreateSecrets < ActiveRecord::Migration[8.0]
  def change
    create_table :secrets, id: :uuid do |t|
      t.references :project, type: :uuid, null: false, foreign_key: true
      t.references :secret_folder, type: :uuid, foreign_key: true

      # Identification
      t.string :key, null: false                 # DATABASE_URL, STRIPE_API_KEY
      t.string :path, null: false                # Full path including folder
      t.text :description

      # Metadata
      t.string :secret_type, default: "string"   # string, json, file, certificate
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

      t.index [ :project_id, :path ], unique: true
      t.index [ :project_id, :key ]
      t.index [ :project_id, :archived ]
    end
  end
end
