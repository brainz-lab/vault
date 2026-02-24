class CreateConnectorExecutions < ActiveRecord::Migration[8.0]
  def change
    create_table :connector_executions, id: :uuid do |t|
      t.uuid :project_id, null: false
      t.uuid :connector_connection_id, null: false
      t.string :action_name, null: false
      t.string :status, null: false
      t.integer :duration_ms
      t.string :input_hash
      t.jsonb :output_summary
      t.text :error_message
      t.string :caller_service
      t.string :caller_request_id
      t.jsonb :metadata, default: {}
      t.datetime :created_at, null: false
    end

    add_index :connector_executions, :project_id
    add_index :connector_executions, :connector_connection_id
    add_index :connector_executions, [ :project_id, :created_at ], name: "idx_connector_execs_project_created"
    add_index :connector_executions, :status

    add_foreign_key :connector_executions, :projects
    add_foreign_key :connector_executions, :connector_connections
  end
end
