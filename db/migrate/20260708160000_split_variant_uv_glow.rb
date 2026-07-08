class SplitVariantUvGlow < ActiveRecord::Migration[8.1]
  def up
    add_column :variants, :glow, :boolean, default: false, null: false
    add_column :variants, :uv, :boolean, default: false, null: false
    # Historic uv_glow was surfaced in the UI as a "UV" badge, so it means UV,
    # not phosphorescence. Preserve that meaning; leave glow at its default.
    execute "UPDATE variants SET uv = uv_glow"
    remove_column :variants, :uv_glow
  end

  def down
    add_column :variants, :uv_glow, :boolean, default: false, null: false
    execute "UPDATE variants SET uv_glow = uv"
    remove_column :variants, :glow
    remove_column :variants, :uv
  end
end
