class AddNotesToSecrets < ActiveRecord::Migration[8.0]
  def change
    add_column :secrets, :notes, :text
  end
end
