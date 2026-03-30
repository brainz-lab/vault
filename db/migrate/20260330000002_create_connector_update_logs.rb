class CreateConnectorUpdateLogs < ActiveRecord::Migration[8.0]
  def change
    create_table :connector_update_logs, id: :uuid do |t|
      t.references :connector, type: :uuid, null: false, foreign_key: true
      t.string :old_version
      t.string :new_version
      t.string :change_type, null: false # minor, patch, breaking
      t.jsonb :change_summary, default: {}
      t.string :status, null: false, default: "pending_review" # auto_applied, pending_review, rejected, applied
      t.datetime :reviewed_at
      t.timestamps
    end

    add_index :connector_update_logs, :status
    add_index :connector_update_logs, :change_type
  end
end
