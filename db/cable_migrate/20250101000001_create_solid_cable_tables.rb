class CreateSolidCableTables < ActiveRecord::Migration[7.1]
  def change
    create_table :solid_cable_messages do |t|
      t.text :channel, null: false
      t.text :payload, null: false
      t.datetime :created_at, null: false
      t.integer :channel_hash, null: false, limit: 8

      t.index :channel
      t.index :channel_hash
      t.index :created_at
    end
  end
end
