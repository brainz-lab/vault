class EnableExtensions < ActiveRecord::Migration[8.0]
  def change
    enable_extension 'pgcrypto' unless extension_enabled?('pgcrypto')
    enable_extension 'timescaledb' unless extension_enabled?('timescaledb')
    enable_extension 'vector' unless extension_enabled?('vector')
  end
end
