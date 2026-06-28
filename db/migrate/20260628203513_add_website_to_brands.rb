class AddWebsiteToBrands < ActiveRecord::Migration[8.1]
  def change
    add_column :brands, :website, :string
  end
end
