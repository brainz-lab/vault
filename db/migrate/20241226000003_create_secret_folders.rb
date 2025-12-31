class CreateSecretFolders < ActiveRecord::Migration[8.0]
  def change
    create_table :secret_folders, id: :uuid do |t|
      t.references :project, type: :uuid, null: false, foreign_key: true

      t.string :name, null: false                # "Database", "API Keys", "OAuth"
      t.string :path, null: false                # "/database", "/api-keys/stripe"
      t.text :description

      t.references :parent_folder, type: :uuid, foreign_key: { to_table: :secret_folders }

      t.timestamps

      t.index [ :project_id, :path ], unique: true
    end
  end
end
