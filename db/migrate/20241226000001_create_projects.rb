class CreateProjects < ActiveRecord::Migration[8.0]
  def change
    enable_extension "pgcrypto" unless extension_enabled?("pgcrypto")

    create_table :projects, id: :uuid do |t|
      # Platform integration
      t.uuid :platform_project_id, null: false
      t.string :name

      # Auto-generated keys for this product
      t.string :api_key
      t.string :ingest_key

      # Settings
      t.string :environment, default: "production"

      t.timestamps

      t.index :platform_project_id, unique: true
      t.index :api_key, unique: true
      t.index :ingest_key, unique: true
    end
  end
end
