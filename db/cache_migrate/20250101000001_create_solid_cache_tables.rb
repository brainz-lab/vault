class CreateSolidCacheTables < ActiveRecord::Migration[7.1]
  def change
    create_table :solid_cache_entries do |t|
      t.binary :key, null: false, limit: 1024
      t.binary :value, null: false, limit: 536870912
      t.datetime :created_at, null: false
      t.integer :key_hash, null: false, limit: 8
      t.integer :byte_size, null: false, limit: 4

      t.index :key_hash, unique: true
      t.index [:key_hash, :byte_size], name: "index_solid_cache_entries_on_key_hash_and_byte_size"
    end
  end
end
