class CreateBuilds < ActiveRecord::Migration[8.1]
  def change
    create_table :builds do |t|
      t.integer :lure_id, null: false
      t.string :name, null: false
      t.integer :length_mm
      t.decimal :weight_g, precision: 8, scale: 2
      t.integer :depth_min_cm
      t.integer :depth_max_cm
      t.integer :action, default: 0, null: false
      t.integer :catches_count, default: 0, null: false
      t.integer :position, default: 0, null: false
      t.timestamps
    end
    add_index :builds, :lure_id
  end
end
