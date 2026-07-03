class AddLocalDescriptionsToBrandsAndLures < ActiveRecord::Migration[8.1]
  def up
    add_column :brands, :local_descriptions, :json, default: {}, null: false
    add_column :lures, :local_descriptions, :json, default: {}, null: false

    # Existing blurbs become the English description so nothing vanishes from
    # show pages when display switches to #description.
    %w[brands lures].each do |table|
      execute <<~SQL
        UPDATE #{table} SET local_descriptions = json_object('en', blurb)
        WHERE blurb IS NOT NULL AND TRIM(blurb) <> ''
      SQL
    end
  end

  def down
    remove_column :brands, :local_descriptions
    remove_column :lures, :local_descriptions
  end
end
