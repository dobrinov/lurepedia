class MakeCatchBuildOptional < ActiveRecord::Migration[8.1]
  def change
    # A catch always records a color (variant); the build/size is optional — the
    # angler may not know the exact configuration. Same-lure integrity between
    # the variant and the build is enforced in the model.
    change_column_null :catches, :build_id, true
  end
end
