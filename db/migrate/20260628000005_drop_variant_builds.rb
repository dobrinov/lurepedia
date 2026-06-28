class DropVariantBuilds < ActiveRecord::Migration[8.1]
  def up
    drop_table :variant_builds
  end

  def down
    create_table :variant_builds do |t|
      t.integer :build_id, null: false
      t.integer :variant_id, null: false
      t.timestamps
      t.index :build_id
      t.index [ :variant_id, :build_id ], unique: true
    end
  end
end
