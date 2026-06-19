class CreateVariantBuilds < ActiveRecord::Migration[8.1]
  def change
    create_table :variant_builds do |t|
      t.integer :variant_id, null: false
      t.integer :build_id, null: false
      t.timestamps
    end
    add_index :variant_builds, [ :variant_id, :build_id ], unique: true
    add_index :variant_builds, :build_id
  end
end
