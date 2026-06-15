class CreateLurepediaSchema < ActiveRecord::Migration[8.1]
  def change
    create_table :lure_types do |t|
      t.string :key, null: false
      t.integer :water_default, null: false, default: 0
      t.timestamps
    end
    add_index :lure_types, :key, unique: true

    create_table :brands do |t|
      t.string :slug, null: false
      t.string :name, null: false
      t.string :country
      t.integer :founded_year
      t.text :blurb
      t.boolean :claimed, null: false, default: false
      t.integer :lures_count, null: false, default: 0
      t.timestamps
    end
    add_index :brands, :slug, unique: true

    create_table :species do |t|
      t.string :slug, null: false
      t.string :key, null: false
      t.string :scientific_name
      t.integer :water, null: false, default: 0
      t.integer :catches_count, null: false, default: 0
      t.integer :lures_count, null: false, default: 0
      t.timestamps
    end
    add_index :species, :slug, unique: true
    add_index :species, :key, unique: true

    create_table :lures do |t|
      t.string :slug, null: false
      t.references :brand, null: false, foreign_key: true
      t.references :lure_type, null: false, foreign_key: true
      t.string :model, null: false
      t.integer :water, null: false, default: 0
      t.integer :depth_min_cm
      t.integer :depth_max_cm
      t.integer :action, null: false, default: 0
      t.text :blurb
      t.string :action_video_url
      t.integer :catches_count, null: false, default: 0
      t.timestamps
    end
    add_index :lures, :slug, unique: true

    create_table :variants do |t|
      t.references :lure, null: false, foreign_key: true
      t.string :name, null: false
      t.integer :size_mm
      t.decimal :weight_g, precision: 8, scale: 2
      t.integer :action, null: false, default: 0
      t.integer :catches_count, null: false, default: 0
      t.timestamps
    end

    create_table :shops do |t|
      t.string :slug, null: false
      t.string :name, null: false
      t.string :url
      t.text :blurb
      t.boolean :promoted, null: false, default: false
      t.boolean :claimed, null: false, default: false
      t.integer :lure_count, null: false, default: 0
      t.timestamps
    end
    add_index :shops, :slug, unique: true

    create_table :buy_links do |t|
      t.references :lure, null: false, foreign_key: true
      t.references :shop, null: false, foreign_key: true
      t.string :url
      t.timestamps
    end

    create_table :catches do |t|
      t.references :user, null: false, foreign_key: true
      t.references :variant, null: false, foreign_key: true
      t.references :species, null: false, foreign_key: true
      t.integer :season
      t.integer :clarity
      t.integer :water_body
      t.integer :wind
      t.integer :time_of_day
      t.string :location
      t.text :note
      t.decimal :length_cm, precision: 8, scale: 2
      t.decimal :weight_g, precision: 8, scale: 2
      t.integer :upvotes_count, null: false, default: 0
      t.integer :comments_count, null: false, default: 0
      t.timestamps
    end

    create_table :comments do |t|
      t.references :catch, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.text :body, null: false
      t.timestamps
    end

    create_table :upvotes do |t|
      t.references :user, null: false, foreign_key: true
      t.references :catch, null: false, foreign_key: true
      t.timestamps
    end
    add_index :upvotes, %i[user_id catch_id], unique: true

    create_table :claims do |t|
      t.references :claimable, polymorphic: true, null: false
      t.references :user, null: false, foreign_key: true
      t.string :email
      t.integer :status, null: false, default: 0
      t.string :verification_token, null: false
      t.datetime :dns_verified_at
      t.timestamps
    end

    create_table :reports do |t|
      t.references :reportable, polymorphic: true, null: false
      t.references :user, null: false, foreign_key: true
      t.integer :reason, null: false, default: 0
      t.text :note
      t.timestamps
    end

    create_table :revisions do |t|
      t.references :subject, polymorphic: true, null: false
      t.references :user, foreign_key: true
      t.string :summary, null: false
      t.timestamps
    end

    create_table :moderation_items do |t|
      t.references :subject, polymorphic: true, null: false
      t.integer :kind, null: false, default: 0
      t.references :submitter, foreign_key: { to_table: :users }
      t.integer :status, null: false, default: 0
      t.boolean :mod_actionable, null: false, default: true
      t.references :reviewer, foreign_key: { to_table: :users }
      t.datetime :reviewed_at
      t.timestamps
    end
  end
end
