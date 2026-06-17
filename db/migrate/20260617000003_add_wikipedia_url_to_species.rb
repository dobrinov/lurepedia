class AddWikipediaUrlToSpecies < ActiveRecord::Migration[8.1]
  def change
    add_column :species, :wikipedia_url, :string
  end
end
