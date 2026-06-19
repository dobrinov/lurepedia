class AddBuildToCatches < ActiveRecord::Migration[8.1]
  def change
    add_column :catches, :build_id, :integer
    add_index :catches, :build_id
  end
end
