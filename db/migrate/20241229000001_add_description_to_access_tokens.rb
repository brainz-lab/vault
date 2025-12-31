class AddDescriptionToAccessTokens < ActiveRecord::Migration[8.0]
  def change
    add_column :access_tokens, :description, :string
  end
end
