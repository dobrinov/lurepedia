require "test_helper"

class SitemapsControllerTest < ActionDispatch::IntegrationTest
  test "index is a sitemap index with one entry per locale" do
    get sitemap_url
    assert_response :success
    assert_equal "application/xml", response.media_type

    entries = response.body.scan(/<loc>(.*?)<\/loc>/).flatten
    assert_equal I18n.available_locales.size, entries.size
    I18n.available_locales.each do |locale|
      assert_includes entries, locale_sitemap_url(locale: locale)
    end
  end

  test "per-locale sitemap lists that locale's URLs with hreflang alternates" do
    get locale_sitemap_url(locale: :de)
    assert_response :success
    assert_equal "application/xml", response.media_type

    # Static index pages are always present; their loc is the requested locale.
    assert_includes response.body, "<loc>#{lures_url(locale: :de)}</loc>"
    # Every locale (plus x-default) appears as an alternate.
    I18n.available_locales.each do |locale|
      assert_includes response.body, %(hreflang="#{locale}")
    end
    assert_includes response.body, %(hreflang="x-default")
  end

  test "unknown locale is not routable" do
    get "/sitemaps/xx.xml"
    assert_response :not_found
  end
end
