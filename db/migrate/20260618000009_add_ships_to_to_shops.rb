class AddShipsToToShops < ActiveRecord::Migration[8.1]
  def change
    add_column :shops, :ships_to, :string
  end
end
