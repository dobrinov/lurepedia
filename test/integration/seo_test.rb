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
end
