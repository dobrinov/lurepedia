class AddRetrieveToCatches < ActiveRecord::Migration[8.1]
  def change
    add_column :catches, :retrieve, :integer
  end
end
