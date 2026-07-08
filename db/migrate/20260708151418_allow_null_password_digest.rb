class AllowNullPasswordDigest < ActiveRecord::Migration[8.1]
  def change
    # OAuth-only users have no password. Password authentication still requires
    # a digest; presence is enforced at the model layer for that path.
    change_column_null :users, :password_digest, true
  end
end
