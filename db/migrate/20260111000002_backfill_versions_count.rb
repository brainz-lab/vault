class BackfillVersionsCount < ActiveRecord::Migration[8.0]
  def up
    # Reset all counter caches in a single efficient query
    execute <<-SQL
      UPDATE secrets
      SET versions_count = (
        SELECT COUNT(*)
        FROM secret_versions
        WHERE secret_versions.secret_id = secrets.id
      )
    SQL
  end

  def down
    # No-op, the column default handles new records
  end
end
