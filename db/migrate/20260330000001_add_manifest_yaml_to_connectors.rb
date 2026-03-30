class AddManifestYamlToConnectors < ActiveRecord::Migration[8.0]
  def change
    add_column :connectors, :manifest_yaml, :text
    add_column :connectors, :manifest_version, :string
    add_column :connectors, :manifest_fetched_at, :datetime
  end
end
