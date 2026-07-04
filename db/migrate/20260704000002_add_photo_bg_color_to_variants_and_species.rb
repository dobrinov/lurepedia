class AddPhotoBgColorToVariantsAndSpecies < ActiveRecord::Migration[8.1]
  def change
    add_column :variants, :photo_bg_color, :string
    add_column :species, :photo_bg_color, :string
  end
end
