class AddUrlToSecrets < ActiveRecord::Migration[8.0]
  def change
    add_column :secrets, :url, :string
    add_index :secrets, [:project_id, :url], where: "url IS NOT NULL"
  end
end
