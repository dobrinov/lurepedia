class AddRevisionToModerationItems < ActiveRecord::Migration[8.1]
  def change
    add_reference :moderation_items, :revision, null: true, foreign_key: true
  end
end
