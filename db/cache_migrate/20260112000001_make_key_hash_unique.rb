class MakeKeyHashUnique < ActiveRecord::Migration[7.1]
  def change
    remove_index :solid_cache_entries, :key_hash
    add_index :solid_cache_entries, :key_hash, unique: true
  end
end
