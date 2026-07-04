class RestoreVariantBuilds < ActiveRecord::Migration[8.1]
  def change
    create_table :variant_builds do |t|
      t.references :variant, null: false, foreign_key: true
      t.references :build, null: false, foreign_key: true
      t.timestamps
    end
    add_index :variant_builds, [ :variant_id, :build_id ], unique: true
  end
end
