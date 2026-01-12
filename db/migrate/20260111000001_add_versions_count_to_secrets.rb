class AddVersionsCountToSecrets < ActiveRecord::Migration[8.0]
  def change
    add_column :secrets, :versions_count, :integer, default: 0, null: false

    # Add index for queries that filter by whether secret has versions
    add_index :secrets, [:project_id, :versions_count], name: "idx_secrets_has_versions"
  end
end
