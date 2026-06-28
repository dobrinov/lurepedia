class DropStaleLureCounters < ActiveRecord::Migration[8.1]
  def change
    # shops.lure_count was never read or maintained — dead denormalization.
    remove_column :shops, :lure_count, :integer, default: 0, null: false

    # species.lures_count is a DISTINCT count (proven lures per species) that a
    # counter_cache can't maintain, so it only ever drifted. It's now computed.
    remove_column :species, :lures_count, :integer, default: 0, null: false
  end
end
