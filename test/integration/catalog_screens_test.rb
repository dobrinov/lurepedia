require "test_helper"

class CatalogScreensTest < ActionDispatch::IntegrationTest
  def setup
    @type = LureType.create!(key: "crankbait")
    @brand = Brand.create!(name: "Strike King")
    @lure = Lure.create!(brand: @brand, lure_type: @type, model: "KVD 1.5", catches_count: 0)
    @build = @lure.builds.create!(name: "Standard", depth_min_cm: 90, depth_max_cm: 150, action: :floating)
    @variant = @lure.variants.create!(name: "Sexy Shad")
    @bass = Species.create!(key: "largemouth_bass", scientific_name: "Micropterus salmoides")
    @member = User.create!(name: "Mia Member", email_address: "mia@example.com", password: "secret123", country: "US")
    @lure.revisions.create!(user: @member, summary: "Created")
    @shop = Shop.create!(name: "TackleDirect", url: "tackledirect.com", promoted: true)
    @reg_shop = Shop.create!(name: "Karls Tackle", url: "karlstackle.com")
    @reg_shop.revisions.create!(user: @member, summary: "Created")
  end

  test "home/lures index renders lure" do
    get "/en"
    assert_response :success
    assert_select ".page-head h1", text: I18n.t("lure.title")
    assert_match "KVD 1.5", response.body
  end

  test "lure detail rich vs sparse" do
    get lure_path(@lure, tab: "caught", locale: :en)
    assert_response :success
    assert_match "KVD 1.5", response.body
    # Sparse: no catches yet → be-first prompt
    assert_match I18n.t("lure.be_first"), response.body
  end

  test "lure detail caught tab shows logged catches when they exist" do
    create_catch(user: @member, variant: @variant, species: @bass, build: @build)
    get lure_path(@lure.reload, tab: "caught", locale: :en)
    assert_response :success
    assert_select ".catch-card"
    assert_no_match I18n.t("lure.be_first"), response.body
  end

  test "lure tabs are separate URLs and variants stay visible" do
    create_catch(user: @member, variant: @variant, species: @bass, build: @build)
    BuyLink.create!(lure: @lure, shop: @shop, url: "https://example.com/buy")

    get lure_path(@lure.reload, tab: "caught", locale: :en)
    assert_response :success
    assert_select ".tabs a", minimum: 3
    assert_match "Sexy Shad", response.body
    assert_select ".grid-catches"

    get lure_path(@lure, tab: "buy", locale: :en)
    assert_response :success
    assert_select ".tabs a.active", text: I18n.t("lure.tab_buy")
    assert_match "TackleDirect", response.body

    get lure_path(@lure, tab: "history", locale: :en)
    assert_response :success
    assert_select ".tabs a.active", text: I18n.t("lure.tab_history")

    sign_in_as(@member)
    get edit_lure_path(@lure, locale: :en)
    assert_response :success
  end

  test "buy link without its own url falls back to the shop website" do
    BuyLink.create!(lure: @lure, shop: @reg_shop, url: nil)

    get lure_path(@lure, tab: "buy", locale: :en)
    assert_response :success
    # Falls back to the shop's own url, not the shops index page.
    assert_select ".card-tooltips" do
      assert_select "a[href=?]", "https://karlstackle.com"
      assert_select "a[href=?]", shops_path(locale: :en), count: 0
    end
  end

  test "buy link prefers its own product url over the shop website" do
    BuyLink.create!(lure: @lure, shop: @reg_shop, url: "https://karlstackle.com/products/kvd")

    get lure_path(@lure, tab: "buy", locale: :en)
    assert_response :success
    assert_select "a[href=?]", "https://karlstackle.com/products/kvd"
  end

  test "proven-for tile is gone from the lure page" do
    get lure_path(@lure, locale: :en)
    assert_response :success
    assert_no_match I18n.t("lure.proven_for"), response.body
  end

  test "type filter chips filter lures" do
    jerk = LureType.create!(key: "jerkbait")
    Lure.create!(brand: @brand, lure_type: jerk, model: "Vision 110")
    get lures_path(locale: :en, type: "crankbait")
    assert_match "KVD 1.5", response.body
    assert_no_match "Vision 110", response.body
  end

  test "species index and detail with tabs" do
    get species_index_path(locale: :en)
    assert_response :success
    assert_match "Largemouth Bass", response.body

    get species_path(@bass, locale: :en)
    assert_response :success
    assert_select ".tabs"
    assert_match I18n.t("species.tab_leaderboard"), response.body
  end

  test "species detail offers add-a-catch shortcuts that preselect the species" do
    sign_in_as(@member)
    target = "catches/new?species=#{@bass.slug}"

    # Hero CTA
    get species_path(@bass, locale: :en)
    assert_response :success
    assert_select "a.btn-primary[href*=?]", target

    # Add-a-catch card in the Catches tab
    get species_path(@bass, tab: "catches", locale: :en)
    assert_response :success
    assert_select "a.add-card[href*=?]", target
  end

  test "species tabs are separate URLs" do
    sp = Species.create!(key: "walleye", scientific_name: "Sander vitreus")
    get species_path(sp, locale: :en)
    assert_response :success
    assert_select ".tabs a", minimum: 4
    get species_path(sp, tab: "history", locale: :en)
    assert_response :success
    assert_select ".tabs a.active", text: I18n.t("species.tab_history")
  end

  test "brand index and detail tabs" do
    get brands_path(locale: :en)
    assert_response :success
    assert_match "Strike King", response.body

    get brand_path(@brand, locale: :en)
    assert_response :success
    assert_select ".tabs"
  end

  test "brand tabs are separate URLs" do
    brand = Brand.create!(name: "Megabass")
    brand.revisions.create!(user: users(:two), summary: "Created")
    get brand_path(brand, locale: :en)
    assert_response :success
    assert_select ".tabs a", minimum: 2
    get brand_path(brand, tab: "history", locale: :en)
    assert_response :success
    assert_select ".tabs a.active", text: I18n.t("brand.tab_history")
  end

  test "shops index pins promoted" do
    get shops_path(locale: :en)
    assert_response :success
    assert_select ".badge-promoted"
    assert_match "TackleDirect", response.body
    assert_match "Karls Tackle", response.body
  end

  test "catches index" do
    create_catch(user: @member, variant: @variant, species: @bass, build: @build)
    get catches_path(locale: :en)
    assert_response :success
    assert_match "Largemouth Bass", response.body
  end

  test "catch detail shows conditions and contributor" do
    sign_in_as(@member) # US member → units resolved imperial from country
    c = create_catch(user: @member, variant: @variant, species: @bass, build: @build, season: :spring, location: "Lake Fork", length_cm: 54.6)
    get catch_path(c, locale: :en)
    assert_response :success
    assert_match "Lake Fork", response.body
    assert_match @member.name, response.body
    assert_match "21.5 in", response.body # length formatted imperial for a US viewer
  end

  test "add screens require login" do
    get new_lure_path(locale: :en)
    assert_redirected_to new_session_path(locale: :en)
    get new_catch_path(locale: :en)
    assert_redirected_to new_session_path(locale: :en)
  end

  test "all add screens render for a signed-in user" do
    sign_in_as(@member)
    [ new_lure_path(locale: :en), new_species_path(locale: :en), new_brand_path(locale: :en),
      new_shop_path(locale: :en), new_catch_path(locale: :en) ].each do |path|
      get path
      assert_response :success, "expected 200 for #{path}"
    end
  end

  test "signed-in member can create a catch" do
    sign_in_as(@member)
    assert_difference -> { Catch.count } => 1, -> { ModerationItem.count } => 1 do
      post catches_path(locale: :en), params: {
        catch: { variant_id: @variant.id, build_id: @build.id, species_id: @bass.id, season: "spring", location: "Pond" }
      }
    end
    assert_response :redirect
  end

  test "guest sees sign-in CTA on lure detail" do
    get lure_path(@lure, locale: :en)
    assert_match I18n.t("lure.add_catch"), response.body
    assert_select "a[href=?]", new_session_path(locale: :en)
  end

  test "lure index header offers only the add-lure CTA" do
    get lures_path(locale: :en)
    assert_response :success
    assert_select ".page-head" do
      assert_select "a.btn", count: 1
      assert_select "a[href=?]", new_lure_path(locale: :en)
    end
    assert_select ".page-head a[href=?]", new_catch_path(locale: :en), count: 0
  end
end
