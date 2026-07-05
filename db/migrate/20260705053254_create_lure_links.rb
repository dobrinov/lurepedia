class CreateLureLinks < ActiveRecord::Migration[8.1]
  def change
    create_table :lure_links do |t|
      t.references :lure, null: false, foreign_key: true
      t.references :related_lure, null: false, foreign_key: { to_table: :lures }

      t.timestamps
    end
    add_index :lure_links, [ :lure_id, :related_lure_id ], unique: true
  end
end
