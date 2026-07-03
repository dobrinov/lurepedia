class AddLocalDescriptionsToSpecies < ActiveRecord::Migration[8.1]
  def change
    add_column :species, :local_descriptions, :json, default: {}, null: false
  end
end
