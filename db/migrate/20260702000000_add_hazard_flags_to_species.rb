class AddHazardFlagsToSpecies < ActiveRecord::Migration[8.1]
  def change
    add_column :species, :venomous, :boolean, default: false, null: false
    add_column :species, :poisonous, :boolean, default: false, null: false
  end
end
