require "test_helper"

class SeoTest < ActionDispatch::IntegrationTest
  def setup
    @type = LureType.create!(key: "crankbait")
    @brand = Brand.create!(name: "Strike King")
    @lure = Lure.create!(brand: @brand, lure_type: @type, model: "KVD 1.5")
    @species = Species.create!(key: "largemouth_bass", scientific_name: "Micropterus salmoides")
  end

  test "sitemap lists urls with locale alternates" do
    get "/sitemap.xml"
    assert_response :success
    assert_equal "application/xml", response.media_type
    assert_match "http://www.example.com/en/lures", response.body
    assert_match "hreflang=\"de\"", response.body
    assert_match "hreflang=\"x-default\"", response.body
    assert_match @lure.slug, response.body
  end

  test "lure page emits canonical, hreflang, and product json-ld" do
    get lure_path(@lure, locale: :en)
    assert_select "link[rel=canonical]"
    assert_select "link[rel=alternate][hreflang=de]"
    assert_match '"@type":"Product"', response.body
  end

  test "localized title and description per locale" do
    get lure_path(@lure, locale: :en)
    assert_select "title", /KVD 1.5/
    assert_select "meta[name=description]"
  end

  test "robots references sitemap" do
    get "/robots.txt"
    assert_match "Sitemap:", response.body
  end

  test "duplicate hosts 301 to the apex, preserving path and query" do
    [ "www.lurepedia.com", "lurepedia.fly.dev" ].each do |duplicate|
      host! duplicate
      get "/en/lures", params: { page: 2 }
      assert_response :moved_permanently
      assert_equal "http://lurepedia.com/en/lures?page=2", response.location
    end
  end

  test "health check is not redirected off duplicate hosts" do
    host! "lurepedia.fly.dev"
    get "/up"
    assert_response :success
  end

  test "canonical host serves pages without a redirect" do
    host! "lurepedia.com"
    get "/en/lures"
    assert_response :success
  end

  test "paginated listings self-canonicalize with matching hreflang" do
    get lures_path(locale: :en, page: 2)
    assert_select "link[rel=canonical][href=?]", "http://www.example.com/en/lures?page=2"
    assert_select "link[rel=alternate][hreflang=de][href=?]", "http://www.example.com/de/lures?page=2"
  end

  test "first page canonical carries no page param" do
    get lures_path(locale: :en)
    assert_select "link[rel=canonical][href=?]", "http://www.example.com/en/lures"

    get lures_path(locale: :en, page: 1)
    assert_select "link[rel=canonical][href=?]", "http://www.example.com/en/lures"
  end

  test "bare root canonicalizes for HEAD requests too" do
    head "/"
    assert_response :moved_permanently
  end
end
