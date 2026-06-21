require "test_helper"

class CatalogTest < ActiveSupport::TestCase
  def setup
    @type = LureType.create!(key: "crankbait")
    @brand = Brand.create!(name: "Strike King")
    @lure = Lure.create!(brand: @brand, lure_type: @type, model: "KVD 1.5")
    @species = Species.create!(key: "largemouth_bass", scientific_name: "Micropterus salmoides")
    @user = User.create!(name: "Casey Rivera", email_address: "c@example.com", password: "secret123")
  end

  test "slug auto-generated and used as param" do
    assert_equal "strike-king-kvd-1-5", @lure.slug
    assert_equal @lure.slug, @lure.to_param
    assert_equal "strike-king", @brand.slug
  end

  test "slug uniqueness disambiguates" do
    other_brand = Brand.create!(name: "Other")
    dup = Lure.create!(brand: other_brand, lure_type: @type, model: "KVD 1.5")
    @brand.update!(name: "Other") # force same source
    assert_not_equal @lure.slug, dup.slug
  end

  test "brand counter cache tracks lures" do
    assert_equal 1, @brand.reload.lures_count
  end

  test "lure belongs to brand and type and reaches catches through variants" do
    variant = @lure.variants.create!(name: "Sexy Shad")
    assert_equal [], @lure.catches.to_a
    create_catch(user: @user, variant: variant, species: @species)
    assert_equal 1, @lure.catches.count
  end

  test "depth range spans the lure's builds" do
    @lure.builds.create!(name: "Shallow", depth_min_cm: 90, depth_max_cm: 150)
    @lure.builds.create!(name: "Deep", depth_min_cm: 120, depth_max_cm: 220)
    assert_equal({ min_cm: 90, max_cm: 220 }, @lure.reload.depth_range)
  end

  test "lure proven scope and counter" do
    variant = @lure.variants.create!(name: "Shad")
    create_catch(user: @user, variant: variant, species: @species)
    assert @lure.reload.proven?
    assert_includes Lure.proven, @lure
  end

  test "species proven lures" do
    variant = @lure.variants.create!(name: "Shad")
    create_catch(user: @user, variant: variant, species: @species)
    assert_includes @species.proven_lures, @lure
    assert_equal 1, @species.reload.catches_count
  end

  test "lure type name via i18n" do
    assert_equal "Crankbait", @type.name
    I18n.with_locale(:de) { assert_equal "Wobbler", @type.name }
  end

  test "species common name via i18n" do
    assert_equal "Largemouth Bass", @species.common_name
  end

  test "brand managed_by? only the holder of a verified claim" do
    owner = users(:two)
    assert_not @brand.managed_by?(owner), "unclaimed brand has no manager"

    claim = @brand.create_claim!(user: owner, email: owner.email_address)
    assert_not @brand.reload.managed_by?(owner), "a pending claim does not confer management"

    claim.verify!
    assert @brand.reload.managed_by?(owner)
    assert_not @brand.managed_by?(@user), "a different user does not manage the brand"
    assert_not @brand.managed_by?(nil)
  end

  test "shop promoted ordering" do
    a = Shop.create!(name: "Regular", url: "regular.com")
    b = Shop.create!(name: "Promo", url: "promo.com", promoted: true)
    assert_equal [ b, a ], Shop.promoted_first.to_a
  end
end
