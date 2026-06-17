class AddPlatformToCatches < ActiveRecord::Migration[8.1]
  def change
    add_column :catches, :platform, :integer
  end
end
