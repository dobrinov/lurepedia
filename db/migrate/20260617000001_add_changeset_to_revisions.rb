class AddChangesetToRevisions < ActiveRecord::Migration[8.1]
  def change
    add_column :revisions, :changeset, :json
  end
end
