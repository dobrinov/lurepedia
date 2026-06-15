class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :email_address, null: false
      t.string :password_digest, null: false
      t.string :name, null: false, default: ""
      t.integer :role, null: false, default: 0
      t.string :country, null: false, default: "US"
      t.string :locale, null: false, default: "en"
      t.integer :units, null: false, default: 0
      t.text :bio

      t.timestamps
    end
    add_index :users, :email_address, unique: true
  end
end
