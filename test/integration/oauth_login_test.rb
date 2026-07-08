require "test_helper"

# Drives the real OmniAuth flow via test_mode: the middleware short-circuits the
# request phase to a redirect to our callback, injecting the mocked auth hash into
# the Rack env exactly as a live provider round-trip would.
class OauthLoginTest < ActionDispatch::IntegrationTest
  setup { OmniAuth.config.test_mode = true }

  teardown do
    OmniAuth.config.test_mode = false
    OmniAuth.config.mock_auth[:google_oauth2] = nil
  end

  def sign_in_with_google(email:, uid: "g-42", name: "Sky Fisher")
    OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new(
      provider: "google_oauth2", uid: uid, info: { email: email, name: name }
    )
    post "/auth/google_oauth2"   # request phase → redirects to the callback
    follow_redirect!             # callback phase, with the mock in env
  end

  test "signs in a brand-new google user" do
    assert_difference "User.count", 1 do
      sign_in_with_google(email: "fresh@example.com")
    end

    assert_redirected_to localized_root_path
    assert cookies[:session_id].present?
  end

  test "signs into the existing account matching the google email" do
    existing = users(:two)

    assert_no_difference "User.count" do
      sign_in_with_google(email: existing.email_address)
    end

    assert_redirected_to localized_root_path
    assert cookies[:session_id].present?
    assert existing.identities.exists?(provider: "google_oauth2")
  end

  test "a provider failure redirects back to sign in" do
    OmniAuth.config.mock_auth[:google_oauth2] = :invalid_credentials
    post "/auth/google_oauth2"
    follow_redirect! while [ 301, 302 ].include?(status) && response.location.include?("/auth/")

    assert_redirected_to new_session_path
    assert_nil cookies[:session_id]
    assert flash[:alert].present?
  end
end
