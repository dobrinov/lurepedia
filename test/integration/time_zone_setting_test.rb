require "test_helper"

# Users can pick a time zone, and timestamps then render in it.
class TimeZoneSettingTest < ActionDispatch::IntegrationTest
  setup { @user = users(:two) }

  test "a user can save their time zone" do
    sign_in_as(@user)
    patch settings_path(locale: :en), params: { user: { time_zone: "Tokyo" }, return_tab: "settings" }
    assert_equal "Tokyo", @user.reload.time_zone
  end

  test "an invalid time zone is rejected" do
    sign_in_as(@user)
    patch settings_path(locale: :en), params: { user: { time_zone: "Mars/Olympus" }, return_tab: "settings" }
    assert_response :unprocessable_entity
    assert_nil @user.reload.time_zone
  end

  test "a timestamp renders in the signed-in user's time zone" do
    rev = Brand.create!(name: "Zone Co").revisions.create!(user: @user, summary: "Created Zone Co")
    instant = Time.utc(2026, 1, 1, 20, 0) # 2026-01-02 05:00 in Tokyo
    rev.update_column(:created_at, instant)

    tokyo = User.create!(name: "Tok", email_address: "tok@example.com", password: "secret123", time_zone: "Tokyo")
    sign_in_as(tokyo)
    get revision_path(rev, locale: :en)
    assert_response :success
    assert_includes response.body, I18n.l(instant.in_time_zone("Tokyo"), format: :long)

    utc_user = User.create!(name: "Utc", email_address: "utc@example.com", password: "secret123") # no zone -> UTC
    sign_in_as(utc_user)
    get revision_path(rev, locale: :en)
    assert_includes response.body, I18n.l(instant.in_time_zone("UTC"), format: :long)
  end
end
