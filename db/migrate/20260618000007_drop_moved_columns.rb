class DropMovedColumns < ActiveRecord::Migration[8.1]
  def up
    # Depth and buoyancy now live on builds.
    remove_column :lures, :depth_min_cm
    remove_column :lures, :depth_max_cm
    remove_column :lures, :action

    # Physical build attributes moved off the color (variant) onto builds.
    remove_column :variants, :size_mm
    remove_column :variants, :weight_g
    remove_column :variants, :action

    change_column_null :catches, :build_id, false
  end

  def down
    change_column_null :catches, :build_id, true

    add_column :variants, :action, :integer, default: 0, null: false
    add_column :variants, :weight_g, :decimal, precision: 8, scale: 2
    add_column :variants, :size_mm, :integer

    add_column :lures, :action, :integer, default: 0, null: false
    add_column :lures, :depth_max_cm, :integer
    add_column :lures, :depth_min_cm, :integer
  end
end
