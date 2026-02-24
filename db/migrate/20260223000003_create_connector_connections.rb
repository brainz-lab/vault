class CreateConnectorConnections < ActiveRecord::Migration[8.0]
  def change
    create_table :connector_connections, id: :uuid do |t|
      t.uuid :project_id, null: false
      t.uuid :connector_id, null: false
      t.uuid :connector_credential_id
      t.string :name
      t.string :status, default: "connected"
      t.jsonb :config, default: {}
      t.boolean :enabled, default: true
      t.datetime :last_executed_at
      t.integer :execution_count, default: 0
      t.text :error_message
      t.jsonb :metadata, default: {}
      t.timestamps
    end

    add_index :connector_connections, [ :project_id, :connector_id ], unique: true, where: "enabled = true", name: "idx_connector_conns_project_connector_enabled"
    add_index :connector_connections, :project_id
    add_index :connector_connections, [ :project_id, :status ], name: "idx_connector_conns_project_status"

    add_foreign_key :connector_connections, :projects
    add_foreign_key :connector_connections, :connectors
    add_foreign_key :connector_connections, :connector_credentials
  end
end
