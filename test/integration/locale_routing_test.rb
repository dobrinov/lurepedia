require "test_helper"

class LocaleRoutingTest < ActionDispatch::IntegrationTest
  test "root redirects to default locale" do
    get "/"
    assert_redirected_to "/en"
  end

  test "signed-in users are served at the bare root without a locale segment" do
    user = User.create!(name: "Locale User", email_address: "loc@example.com", password: "secret123", country: "US")
    sign_in_as(user)

    get "/"
    assert_response :success
  end

  test "signed-in users get locale-free generated links" do
    user = User.create!(name: "Locale User", email_address: "loc@example.com", password: "secret123", country: "US", locale: "de")
    sign_in_as(user)

    get "/"
    assert_response :success
    assert_select "html[lang=?]", "de"
    # The wordmark links home with no locale prefix.
    assert_select "a.wordmark[href=?]", "/"
  end

  test "localized root renders with html lang" do
    get "/en"
    assert_response :success
    assert_select "html[lang=?]", "en"
  end

  test "german locale sets lang attribute" do
    get "/de"
    assert_response :success
    assert_select "html[lang=?]", "de"
  end

  test "unsupported locale falls through to not found" do
    get "/xx/lures"
    assert_response :not_found
  end

  test "generated links keep the active locale" do
    get "/de"
    assert_response :success
    assert_select "a[href^=?]", "/de/"
  end

  test "hreflang alternate tags present for every locale" do
    get "/en"
    I18n.available_locales.each do |loc|
      assert_select "link[rel=alternate][hreflang=?]", loc.to_s
    end
    assert_select "link[rel=alternate][hreflang=?]", "x-default"
  end

  test "canonical tag present" do
    get "/en"
    assert_select "link[rel=canonical]"
  end
end
