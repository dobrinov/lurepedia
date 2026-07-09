class CreateTechniques < ActiveRecord::Migration[8.1]
  def up
    create_table :techniques do |t|
      t.string :key, null: false
      t.timestamps
    end
    add_index :techniques, :key, unique: true

    create_table :lure_techniques do |t|
      t.references :lure, null: false, foreign_key: true
      t.references :technique, null: false, foreign_key: true
      t.timestamps
    end
    add_index :lure_techniques, [ :lure_id, :technique_id ], unique: true

    # Fixed reference vocabulary. Seeded here (not db/seeds.rb, which is a no-op
    # in production) so every environment has these rows after db:prepare.
    %w[spinning jigging trolling drifting other].each do |k|
      execute "INSERT INTO techniques (key, created_at, updated_at) VALUES ('#{k}', datetime('now'), datetime('now'))"
    end
  end

  def down
    drop_table :lure_techniques
    drop_table :techniques
  end
end
