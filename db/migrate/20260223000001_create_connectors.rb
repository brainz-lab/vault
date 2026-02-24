class CreateConnectors < ActiveRecord::Migration[8.0]
  def change
    create_table :connectors, id: :uuid do |t|
      t.string :piece_name, null: false
      t.string :display_name, null: false
      t.text :description
      t.string :logo_url
      t.string :category, null: false
      t.string :connector_type, null: false
      t.string :auth_type
      t.jsonb :auth_schema, default: {}
      t.string :version
      t.string :package_name
      t.jsonb :actions, default: []
      t.jsonb :triggers, default: []
      t.jsonb :metadata, default: {}
      t.boolean :enabled, default: true
      t.boolean :installed, default: false
      t.timestamps
    end

    add_index :connectors, :piece_name, unique: true
    add_index :connectors, :category
    add_index :connectors, :connector_type
    add_index :connectors, :enabled
  end
end
