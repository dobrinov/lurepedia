require "test_helper"

class CatalogScreensTest < ActionDispatch::IntegrationTest
  def setup
    @type = LureType.create!(key: "crankbait")
    @brand = Brand.create!(name: "Strike King")
    @lure = Lure.create!(brand: @brand, lure_type: @type, model: "KVD 1.5", catches_count: 0, depth_min_cm: 90, depth_max_cm: 150)
    @variant = @lure.variants.create!(name: "Sexy Shad")
    @bass = Species.create!(key: "largemouth_bass", scientific_name: "Micropterus salmoides")
    @member = User.create!(name: "Mia Member", email_address: "mia@example.com", password: "secret123", country: "US")
    @lure.revisions.create!(user: @member, summary: "Created")
    @shop = Shop.create!(name: "TackleDirect", promoted: true)
    @reg_shop = Shop.create!(name: "Karls Tackle")
    @reg_shop.revisions.create!(user: @member, summary: "Created")
  end

  test "home/lures index renders lure" do
    get "/en"
    assert_response :success
    assert_select "h1", text: I18n.t("home.hero_title")
    assert_match "KVD 1.5", response.body
  end

  test "lure detail rich vs sparse" do
    get lure_path(@lure, locale: :en)
    assert_response :success
    assert_match "KVD 1.5", response.body
    # Sparse: no catches yet → be-first prompt
    assert_match I18n.t("lure.be_first"), response.body
  end

  test "lure detail shows proof when catches exist" do
    Catch.create!(user: @member, variant: @variant, species: @bass)
    get lure_path(@lure.reload, locale: :en)
    assert_response :success
    assert_select ".badge-proof"
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

  test "brand index and detail tabs" do
    get brands_path(locale: :en)
    assert_response :success
    assert_match "Strike King", response.body

    get brand_path(@brand, locale: :en)
    assert_response :success
    assert_select ".tabs"
  end

  test "shops index pins promoted" do
    get shops_path(locale: :en)
    assert_response :success
    assert_select ".badge-promoted"
    assert_match "TackleDirect", response.body
    assert_match "Karls Tackle", response.body
  end

  test "catches index" do
    Catch.create!(user: @member, variant: @variant, species: @bass)
    get catches_path(locale: :en)
    assert_response :success
    assert_match "Largemouth Bass", response.body
  end

  test "catch detail shows conditions and contributor" do
    c = Catch.create!(user: @member, variant: @variant, species: @bass, season: :spring, location: "Lake Fork", length_cm: 54.6)
    get catch_path(c, locale: :en)
    assert_response :success
    assert_match "Lake Fork", response.body
    assert_match @member.name, response.body
    assert_match "21.5 in", response.body # length formatted imperial for en
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
        catch: { variant_id: @variant.id, species_id: @bass.id, season: "spring", location: "Pond" }
      }
    end
    assert_response :redirect
  end

  test "guest sees sign-in CTA on lure detail" do
    get lure_path(@lure, locale: :en)
    assert_match I18n.t("auth.sign_in_to_contribute"), response.body
  end
end
