require "test_helper"

class AdminBansTest < ActionDispatch::IntegrationTest
  def setup
    @admin = users(:one)
    @user = users(:two)
  end

  test "admin can issue a ban from a preset" do
    sign_in_as(@admin)
    assert_difference -> { @user.bans.count }, 1 do
      post admin_user_bans_path(@user, locale: :en), params: {
        ban: { reason: "spamming", preset: "contributions", expires_at: "" }
      }
    end
    assert @user.reload.blocked_from?(:catches)
  end

  test "admin can issue a ban with custom capabilities" do
    sign_in_as(@admin)
    post admin_user_bans_path(@user, locale: :en), params: {
      ban: { reason: "edits only", capabilities: %w[catalog], expires_at: "" }
    }
    assert @user.reload.blocked_from?(:catalog)
    assert_not @user.blocked_from?(:catches)
  end

  test "admin can revoke a ban" do
    ban = Ban.create!(user: @user, issued_by: @admin, reason: "x", capabilities: %w[catches])
    sign_in_as(@admin)
    patch revoke_admin_user_ban_path(@user, ban, locale: :en)
    assert_not_nil ban.reload.revoked_at
    assert_equal @admin, ban.revoked_by
  end

  test "non-admin cannot reach ban management" do
    sign_in_as(@user)
    get admin_user_bans_path(@user, locale: :en)
    # Signed-in users get locale-free URLs.
    assert_redirected_to localized_root_path
  end

  test "ban history lists all bans for the user" do
    Ban.create!(user: @user, issued_by: @admin, reason: "old", capabilities: %w[catches], revoked_at: Time.current, revoked_by: @admin)
    Ban.create!(user: @user, issued_by: @admin, reason: "current", capabilities: %w[catalog])
    sign_in_as(@admin)
    get admin_user_bans_path(@user, locale: :en)
    assert_response :success
    assert_select "body", text: /old/
    assert_select "body", text: /current/
  end
end
