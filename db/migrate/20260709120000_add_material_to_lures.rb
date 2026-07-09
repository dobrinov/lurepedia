class AddMaterialToLures < ActiveRecord::Migration[8.1]
  def change
    add_column :lures, :material, :integer # nullable — nil means "unknown"
  end
end
