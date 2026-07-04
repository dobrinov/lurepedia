class AddPhotoCropToVariantsAndSpecies < ActiveRecord::Migration[8.1]
  def change
    %i[variants species].each do |table|
      add_column table, :photo_crop_x, :integer
      add_column table, :photo_crop_y, :integer
      add_column table, :photo_crop_w, :integer
      add_column table, :photo_crop_h, :integer
    end
  end
end
