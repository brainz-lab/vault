class CreateAssistantChats < ActiveRecord::Migration[8.1]
  def change
    create_table :assistant_chats do |t|
      t.integer :user_id
      t.string :title
      t.timestamps
    end

    create_table :assistant_messages do |t|
      t.references :assistant_chat, null: false, foreign_key: true
      t.integer :role, default: 0
      t.text :content
      t.jsonb :metadata, default: {}
      t.timestamps
    end

    add_index :assistant_chats, :user_id
    add_index :assistant_messages, [:assistant_chat_id, :created_at]
  end
end
