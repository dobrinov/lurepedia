class AddAppliedToRevisions < ActiveRecord::Migration[8.1]
  def change
    # A revision is "applied" once its change lives on the record. Direct edits
    # and creation entries are applied on the spot (the column default); a
    # pending suggestion stays unapplied until a moderator approves it.
    add_column :revisions, :applied, :boolean, default: true, null: false
  end
end
