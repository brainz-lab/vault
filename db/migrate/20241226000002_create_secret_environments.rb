class CreateSecretEnvironments < ActiveRecord::Migration[8.0]
  def change
    create_table :secret_environments, id: :uuid do |t|
      t.references :project, type: :uuid, null: false, foreign_key: true

      t.string :name, null: false                # production, staging, development
      t.string :slug, null: false                # URL-safe identifier
      t.text :description

      # Protection
      t.boolean :protected, default: false       # Require approval for changes
      t.boolean :locked, default: false          # No changes allowed

      # Inheritance
      t.references :parent_environment, type: :uuid, foreign_key: { to_table: :secret_environments }

      # Settings
      t.string :color                            # For UI display
      t.integer :position, default: 0            # Sort order

      t.timestamps

      t.index [:project_id, :slug], unique: true
      t.index [:project_id, :name], unique: true
    end
  end
end
