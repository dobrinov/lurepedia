class AddLocalNamesToSpecies < ActiveRecord::Migration[8.1]
  def change
    add_column :species, :local_names, :json, default: {}, null: false
  end
end
