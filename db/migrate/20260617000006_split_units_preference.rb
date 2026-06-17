class SplitUnitsPreference < ActiveRecord::Migration[8.1]
  def up
    add_column :users, :length_units, :integer, default: 0, null: false
    add_column :users, :weight_units, :integer, default: 0, null: false
    add_column :users, :depth_units, :integer, default: 0, null: false

    # Backfill the new per-measurement preferences from the old combined one.
    execute "UPDATE users SET length_units = units, weight_units = units, depth_units = units"

    remove_column :users, :units
  end

  def down
    add_column :users, :units, :integer, default: 0, null: false
    execute "UPDATE users SET units = length_units"

    remove_column :users, :length_units
    remove_column :users, :weight_units
    remove_column :users, :depth_units
  end
end
