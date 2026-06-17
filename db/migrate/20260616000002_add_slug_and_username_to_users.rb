class AddSlugAndUsernameToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :slug, :string
    add_column :users, :username, :string
    add_index :users, :slug, unique: true
    add_index :users, :username, unique: true

    # Backfill slugs for existing rows so the NOT NULL goal holds going forward.
    reversible do |dir|
      dir.up do
        User.reset_column_information
        User.find_each do |u|
          base = u.name.to_s.parameterize.presence || "angler"
          u.update_columns(slug: "#{base}-#{SecureRandom.alphanumeric(4).downcase}")
        end
        change_column_null :users, :slug, false
      end
    end
  end
end
