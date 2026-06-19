class AddDefaultVariantToLures < ActiveRecord::Migration[8.1]
  def change
    add_column :lures, :default_variant_id, :integer
    add_index :lures, :default_variant_id
  end
end
