require "test_helper"

class SitemapsControllerTest < ActionDispatch::IntegrationTest
  test "index is a sitemap index with one entry per indexable locale" do
    get sitemap_url
    assert_response :success
    assert_equal "application/xml", response.media_type

    entries = response.body.scan(/<loc>(.*?)<\/loc>/).flatten
    assert_equal Locales.indexable.size, entries.size
    Locales.indexable.each do |locale|
      assert_includes entries, locale_sitemap_url(locale: locale)
    end
    (I18n.available_locales - Locales.indexable).each do |locale|
      assert_not_includes entries, locale_sitemap_url(locale: locale)
    end
  end

  test "per-locale sitemap lists that locale's URLs with hreflang alternates" do
    get locale_sitemap_url(locale: :en)
    assert_response :success
    assert_equal "application/xml", response.media_type

    # Static index pages are always present; their loc is the requested locale.
    assert_includes response.body, "<loc>#{lures_url(locale: :en)}</loc>"
    # Every indexable locale (plus x-default) appears as an alternate; the
    # noindex ones must not, or we'd advertise pages we're keeping out.
    Locales.indexable.each do |locale|
      assert_includes response.body, %(hreflang="#{locale}")
    end
    (I18n.available_locales - Locales.indexable).each do |locale|
      assert_not_includes response.body, %(hreflang="#{locale}")
    end
    assert_includes response.body, %(hreflang="x-default")
  end

  test "non-indexable locale has no sitemap" do
    get locale_sitemap_url(locale: :de)
    assert_response :not_found
  end

  test "unknown locale is not routable" do
    get "/sitemaps/xx.xml"
    assert_response :not_found
  end
end
