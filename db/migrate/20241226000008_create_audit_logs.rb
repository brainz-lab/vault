class CreateAuditLogs < ActiveRecord::Migration[8.0]
  def change
    create_table :audit_logs, id: :uuid do |t|
      t.references :project, type: :uuid, null: false, foreign_key: true

      # What happened
      t.string :action, null: false              # read, create, update, delete, rotate
      t.string :resource_type, null: false       # secret, environment, token, policy
      t.uuid :resource_id
      t.string :resource_path                    # Full path for secrets

      # Who did it
      t.string :actor_type, null: false          # user, token, system
      t.string :actor_id
      t.string :actor_name                       # For display

      # Context
      t.string :ip_address
      t.string :user_agent
      t.string :request_id

      # Environment
      t.string :environment                      # Which environment was accessed

      # Details
      t.jsonb :metadata, default: {}
      # {
      #   version: 5,
      #   previous_version: 4,
      #   change_note: "Updated for new API version"
      # }

      # Result
      t.boolean :success, default: true
      t.text :error_message

      t.datetime :created_at, null: false

      t.index [:project_id, :created_at]
      t.index [:project_id, :resource_type, :resource_id], name: "idx_audit_logs_resource"
      t.index [:project_id, :actor_type, :actor_id], name: "idx_audit_logs_actor"
      t.index [:project_id, :action]
    end

    # Make it append-only (no updates/deletes)
    reversible do |dir|
      dir.up do
        execute <<-SQL
          CREATE RULE audit_logs_no_update AS ON UPDATE TO audit_logs DO INSTEAD NOTHING;
          CREATE RULE audit_logs_no_delete AS ON DELETE TO audit_logs DO INSTEAD NOTHING;
        SQL
      end
      dir.down do
        execute <<-SQL
          DROP RULE IF EXISTS audit_logs_no_update ON audit_logs;
          DROP RULE IF EXISTS audit_logs_no_delete ON audit_logs;
        SQL
      end
    end
  end
end
