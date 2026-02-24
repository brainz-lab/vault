class CreateConnectorCredentials < ActiveRecord::Migration[8.0]
  def change
    create_table :connector_credentials, id: :uuid do |t|
      t.uuid :project_id, null: false
      t.uuid :connector_id, null: false
      t.string :name, null: false
      t.string :auth_type, null: false
      t.binary :encrypted_credentials, null: false
      t.binary :encryption_iv, null: false
      t.string :encryption_key_id, null: false
      t.binary :encrypted_refresh_token
      t.binary :refresh_token_iv
      t.string :refresh_token_key_id
      t.datetime :token_expires_at
      t.string :status, default: "active"
      t.datetime :last_verified_at
      t.datetime :last_used_at
      t.integer :usage_count, default: 0
      t.text :error_message
      t.jsonb :metadata, default: {}
      t.timestamps
    end

    add_index :connector_credentials, [ :project_id, :connector_id, :name ], unique: true, name: "idx_connector_creds_project_connector_name"
    add_index :connector_credentials, :project_id
    add_index :connector_credentials, :connector_id
    add_index :connector_credentials, [ :project_id, :status ], name: "idx_connector_creds_project_status"

    add_foreign_key :connector_credentials, :projects
    add_foreign_key :connector_credentials, :connectors
  end
end
