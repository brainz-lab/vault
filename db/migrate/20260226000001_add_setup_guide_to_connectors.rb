class AddSetupGuideToConnectors < ActiveRecord::Migration[8.0]
  def change
    add_column :connectors, :setup_guide, :jsonb, default: {}, null: false
  end
end
