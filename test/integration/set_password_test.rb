require "test_helper"

class SetPasswordTest < ActionDispatch::IntegrationTest
  test "an oauth-first user can set a password and then authenticate with it" do
    user = User.create!(name: "OAuth Only", email_address: "oauthonly@example.com", oauth_signup: true)
    assert_not user.password_set?

    sign_in_as(user)
    patch password_settings_path(locale: :en),
      params: { user: { password: "sup3rsecret", password_confirmation: "sup3rsecret" } }

    assert_redirected_to profile_path(user, tab: "settings", locale: user.locale)
    assert user.reload.password_set?
    assert user.authenticate("sup3rsecret")
  end

  test "changing an existing password requires the correct current password" do
    user = users(:one) # password: "password"
    sign_in_as(user)

    patch password_settings_path(locale: :en),
      params: { user: { current_password: "wrong", password: "newpassword", password_confirmation: "newpassword" } }

    assert_response :unprocessable_entity
    assert user.reload.authenticate("password"), "password should be unchanged"
  end

  test "an existing user changes their password with the right current password" do
    user = users(:one)
    sign_in_as(user)

    patch password_settings_path(locale: :en),
      params: { user: { current_password: "password", password: "brandnewpass", password_confirmation: "brandnewpass" } }

    assert_redirected_to profile_path(user, tab: "settings", locale: user.locale)
    assert user.reload.authenticate("brandnewpass")
  end

  test "a confirmation mismatch is rejected" do
    user = User.create!(name: "OAuth Two", email_address: "oauth2@example.com", oauth_signup: true)
    sign_in_as(user)

    patch password_settings_path(locale: :en),
      params: { user: { password: "onepassword", password_confirmation: "different" } }

    assert_response :unprocessable_entity
    assert_not user.reload.password_set?
  end

  test "a blank password is rejected" do
    user = User.create!(name: "OAuth Three", email_address: "oauth3@example.com", oauth_signup: true)
    sign_in_as(user)

    patch password_settings_path(locale: :en),
      params: { user: { password: "", password_confirmation: "" } }

    assert_response :unprocessable_entity
    assert_not user.reload.password_set?
  end
end
