class MoveWaterToBuilds < ActiveRecord::Migration[8.1]
  class MigrationBuild < ActiveRecord::Base
    self.table_name = "builds"
  end

  class MigrationLure < ActiveRecord::Base
    self.table_name = "lures"
  end

  def up
    add_column :builds, :water, :integer, default: 0, null: false
    MigrationBuild.reset_column_information

    # Each build inherits its lure's former water type.
    MigrationLure.find_each do |lure|
      MigrationBuild.where(lure_id: lure.id).update_all(water: lure.water || 0)
    end

    remove_column :lures, :water
  end

  def down
    add_column :lures, :water, :integer, default: 0, null: false
    execute <<~SQL.squish
      UPDATE lures SET water = COALESCE(
        (SELECT water FROM builds WHERE builds.lure_id = lures.id ORDER BY builds.id LIMIT 1), 0)
    SQL
    remove_column :builds, :water
  end
end
