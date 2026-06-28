require "test_helper"

class BuyLinksControllerTest < ActionDispatch::IntegrationTest
  def setup
    @type = LureType.create!(key: "crankbait")
    @brand = Brand.create!(name: "Strike King")
    @lure = Lure.create!(brand: @brand, lure_type: @type, model: "KVD 1.5", catches_count: 0)
    @shop = Shop.create!(name: "TackleDirect", url: "tackledirect.com")
    @admin = users(:one)
    @member = users(:two)
  end

  test "requires login" do
    assert_no_difference -> { BuyLink.count } do
      post buy_links_path(@lure, locale: :en), params: { shop: @shop.slug }
    end
    assert_redirected_to new_session_path(locale: :en)
  end

  test "member adds a buy link and it queues for moderation" do
    sign_in_as(@member)
    assert_difference -> { BuyLink.count } => 1, -> { ModerationItem.count } => 1 do
      post buy_links_path(@lure, locale: :en), params: { shop: @shop.slug, url: "tackledirect.com/kvd" }
    end
    assert_redirected_to lure_path(@lure, tab: "buy")
    link = BuyLink.last
    assert_equal @lure, link.lure
    assert_equal @shop, link.shop
    assert_equal "tackledirect.com/kvd", link.url
    item = ModerationItem.last
    assert item.kind_catalog?
    assert_equal link, item.subject
  end

  test "admin adds a buy link directly without moderation" do
    sign_in_as(@admin)
    assert_difference -> { BuyLink.count } => 1, -> { ModerationItem.count } => 0 do
      post buy_links_path(@lure, locale: :en), params: { shop: @shop.slug }
    end
    assert_redirected_to lure_path(@lure, tab: "buy")
  end

  test "member creates a new shop inline and links it" do
    sign_in_as(@member)
    assert_difference -> { Shop.count } => 1, -> { BuyLink.count } => 1 do
      post buy_links_path(@lure, locale: :en),
           params: { shop_source: "new", new_shop: { name: "Fresh Tackle", url: "freshtackle.com", ships_to: "US, CA" } }
    end
    assert_redirected_to lure_path(@lure, tab: "buy")
    shop = Shop.find_by(name: "Fresh Tackle")
    assert_equal "freshtackle.com", shop.url
    assert_equal @lure, shop.lures.first
    # Both the new shop and the buy link are queued for review.
    assert_equal 2, ModerationItem.where(kind: :catalog).count
    assert shop.revisions.any?
  end

  test "new shop with a blank name is rejected with the model error" do
    sign_in_as(@member)
    assert_no_difference -> { Shop.count } do
      post buy_links_path(@lure, locale: :en), params: { shop_source: "new", new_shop: { name: "", url: "x.com" } }
    end
    assert_redirected_to lure_path(@lure, tab: "buy")
    assert_match(/name/i, flash[:alert])
    assert_no_match(/slug/i, flash[:alert])
  end

  test "missing shop is rejected" do
    sign_in_as(@member)
    assert_no_difference -> { BuyLink.count } do
      post buy_links_path(@lure, locale: :en), params: { shop: "nope" }
    end
    assert_redirected_to lure_path(@lure, tab: "buy")
    assert_equal I18n.t("buy_link.shop_required"), flash[:alert]
  end

  test "duplicate shop is rejected" do
    BuyLink.create!(lure: @lure, shop: @shop, url: "x")
    sign_in_as(@member)
    assert_no_difference -> { BuyLink.count } do
      post buy_links_path(@lure, locale: :en), params: { shop: @shop.slug }
    end
    assert_equal I18n.t("buy_link.already_listed"), flash[:alert]
  end
end
