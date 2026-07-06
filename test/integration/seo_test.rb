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

  test "lure page emits canonical, hreflang, and breadcrumb json-ld but no product json-ld" do
    get lure_path(@lure, locale: :en)
    assert_select "link[rel=canonical]"
    assert_select "link[rel=alternate][hreflang=de]"
    # No Product JSON-LD: without offers/review/aggregateRating (none of which
    # we can honestly provide), Google flags it as an invalid rich-result item.
    assert_no_match '"@type":"Product"', response.body
    assert_match '"@type":"BreadcrumbList"', response.body
    assert_select "meta[property='og:type'][content=product]"
  end

  test "non-lure pages keep the website og:type" do
    get lures_path(locale: :en)
    assert_select "meta[property='og:type'][content=website]"
  end

  test "species page emits taxon and breadcrumb json-ld" do
    get species_path(@species, locale: :en)
    assert_match '"@type":"Taxon"', response.body
    assert_match @species.scientific_name, response.body
    assert_match '"@type":"BreadcrumbList"', response.body
  end

  test "shop page emits online store and breadcrumb json-ld" do
    shop = Shop.create!(name: "Tackle Direct", url: "tackledirect.example")
    get shop_path(shop, locale: :en)
    assert_match '"@type":"OnlineStore"', response.body
    assert_match '"url":"https://tackledirect.example"', response.body
    assert_match '"@type":"BreadcrumbList"', response.body
  end

  test "catch page emits social media posting and breadcrumb json-ld" do
    user = User.create!(email_address: "angler@example.com", password: "s3cret-pass", name: "Angler Andy")
    variant = Variant.create!(lure: @lure, name: "Chartreuse")
    a_catch = Catch.create!(user: user, variant: variant, species: @species)

    get catch_path(a_catch, locale: :en)
    assert_match '"@type":"SocialMediaPosting"', response.body
    assert_match '"@type":"Person"', response.body
    assert_match '"@type":"BreadcrumbList"', response.body
  end

  test "localized title and description per locale" do
    get lure_path(@lure, locale: :en)
    assert_select "title", /KVD 1.5/
    assert_select "meta[name=description]"
  end

  test "lure page surfaces aggregated catch conditions on the canonical url" do
    user = User.create!(email_address: "summary@example.com", password: "s3cret-pass", name: "Summary Sam")
    variant = Variant.create!(lure: @lure, name: "Sexy Shad")
    2.times { Catch.create!(user: user, variant: variant, species: @species, season: :spring, water_body: :lake) }

    get lure_path(@lure, locale: :en)
    assert_match "What the catches show", response.body
    assert_match "Spring ×2", response.body
    assert_select "a[href=?]", species_path(@species, locale: :en), text: /×2/
  end

  test "unproven lure page has no catch summary" do
    get lure_path(@lure, locale: :en)
    assert_no_match "What the catches show", response.body
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
