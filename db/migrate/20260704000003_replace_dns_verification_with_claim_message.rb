class ReplaceDnsVerificationWithClaimMessage < ActiveRecord::Migration[8.1]
  def change
    add_column :claims, :message, :text
    remove_column :claims, :verification_token, :string, null: false
    remove_column :claims, :dns_verified_at, :datetime
  end
end
