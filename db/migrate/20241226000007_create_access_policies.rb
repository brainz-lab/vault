class CreateAccessPolicies < ActiveRecord::Migration[8.0]
  def change
    create_table :access_policies, id: :uuid do |t|
      t.references :project, type: :uuid, null: false, foreign_key: true

      t.string :name, null: false
      t.text :description

      # Who this policy applies to
      t.string :principal_type, null: false      # user, team, token
      t.string :principal_id                     # User ID, Team ID, or Token ID

      # What they can access
      t.string :environments, array: true, default: []
      t.string :paths, array: true, default: []  # Glob patterns: "/database/*"

      # What they can do
      t.string :permissions, array: true, default: []
      # read - View secret values
      # write - Create/update secrets
      # delete - Delete secrets
      # admin - Manage access policies

      # Conditions
      t.jsonb :conditions, default: {}
      # {
      #   require_mfa: true,
      #   allowed_ips: ["10.0.0.0/8"],
      #   time_window: { start: "09:00", end: "18:00", timezone: "UTC" }
      # }

      t.boolean :enabled, default: true

      t.timestamps

      t.index [ :project_id, :principal_type, :principal_id ], name: "idx_access_policies_principal"
    end
  end
end
