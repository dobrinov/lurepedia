class DropClaimedBooleanFromClaimables < ActiveRecord::Migration[8.1]
  def change
    # Ownership has one source of truth: a verified Claim. The cached `claimed`
    # boolean only duplicated it (and already drifted in seed data), so it goes;
    # Brand/Shop#claimed? now derive from the claim.
    remove_column :brands, :claimed, :boolean, default: false, null: false
    remove_column :shops, :claimed, :boolean, default: false, null: false
  end
end
