class CreateProviderKeys < ActiveRecord::Migration[8.0]
  def change
    create_table :provider_keys, id: :uuid do |t|
      t.references :project, type: :uuid, null: true, foreign_key: true
      t.string :name, null: false
      t.string :provider, null: false  # openai, anthropic, google, azure, etc.
      t.string :model_type, null: false, default: "llm"  # llm, embedding, image, tts, etc.
      t.binary :encrypted_key, null: false
      t.binary :encryption_iv, null: false
      t.string :encryption_key_id, null: false
      t.string :key_prefix  # e.g., "sk-proj-..." for OpenAI (last 4 chars for display)
      t.boolean :global, null: false, default: false
      t.boolean :active, null: false, default: true
      t.integer :priority, null: false, default: 0  # for ordering when multiple keys exist
      t.jsonb :settings, null: false, default: {}  # rate limits, quotas, etc.
      t.jsonb :metadata, null: false, default: {}  # extra info
      t.datetime :last_used_at
      t.integer :usage_count, null: false, default: 0
      t.datetime :expires_at

      t.timestamps
    end

    add_index :provider_keys, :provider
    add_index :provider_keys, :global
    add_index :provider_keys, :active
    add_index :provider_keys, [ :project_id, :provider, :active ]
    add_index :provider_keys, [ :global, :provider, :active ]
  end
end
