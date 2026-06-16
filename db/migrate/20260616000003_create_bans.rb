class CreateBans < ActiveRecord::Migration[8.1]
  def change
    create_table :bans do |t|
      t.references :user, null: false, foreign_key: true
      t.references :issued_by, null: false, foreign_key: { to_table: :users }
      t.references :revoked_by, null: true, foreign_key: { to_table: :users }
      t.text :reason, null: false
      t.json :capabilities, null: false, default: []
      t.datetime :expires_at
      t.datetime :revoked_at
      t.timestamps
    end
    add_index :bans, [ :user_id, :revoked_at, :expires_at ]
  end
end
