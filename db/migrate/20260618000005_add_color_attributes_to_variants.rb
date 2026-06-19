class AddColorAttributesToVariants < ActiveRecord::Migration[8.1]
  def change
    add_column :variants, :best_for, :string
    add_column :variants, :uv_glow, :boolean, default: false, null: false
  end
end
