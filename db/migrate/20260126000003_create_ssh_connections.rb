class CreateSshConnections < ActiveRecord::Migration[8.0]
  def change
    create_table :ssh_connections, id: :uuid do |t|
      t.references :project, type: :uuid, null: false, foreign_key: true
      t.references :ssh_client_key, type: :uuid, foreign_key: true

      # Connection details
      t.string :name, null: false
      t.string :host, null: false
      t.integer :port, default: 22, null: false
      t.string :username, null: false

      # Jump host (self-referential for ProxyJump)
      t.uuid :jump_connection_id
      t.index :jump_connection_id

      # Connection options (JSONB for flexible SSH options)
      t.jsonb :options, default: {}

      # Metadata
      t.text :description
      t.jsonb :metadata, default: {}

      # Status
      t.boolean :archived, default: false
      t.datetime :archived_at

      t.timestamps

      t.index [ :project_id, :name ], unique: true, where: "archived = false", name: "idx_ssh_connections_project_name_active"
      t.index [ :project_id, :archived ]
    end

    add_foreign_key :ssh_connections, :ssh_connections, column: :jump_connection_id
  end
end
