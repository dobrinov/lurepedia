class AddShipsWorldwideToShops < ActiveRecord::Migration[8.1]
  def change
    add_column :shops, :ships_worldwide, :boolean, default: false, null: false
  end
end
