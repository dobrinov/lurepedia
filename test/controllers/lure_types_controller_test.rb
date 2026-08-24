require "test_helper"

class LureTypesControllerTest < ActionDispatch::IntegrationTest
  def setup
    @crankbait = LureType.create!(key: "crankbait")
    @jerkbait = LureType.create!(key: "jerkbait")
    @brand = Brand.create!(name: "Strike King")
    @crank = Lure.create!(brand: @brand, lure_type: @crankbait, model: "KVD 1.5")
    @jerk = Lure.create!(brand: @brand, lure_type: @jerkbait, model: "Thunder Stick")
  end

  test "index links every type hub" do
    get lure_types_path(locale: :en)
    assert_response :success
    assert_select "a[href=?]", lure_type_path(@crankbait, locale: :en)
    assert_select "a[href=?]", lure_type_path(@jerkbait, locale: :en)
  end

  test "show lists only that type's lures" do
    get lure_type_path(@crankbait, locale: :en)
    assert_response :success
    assert_select "a[href=?]", lure_path(@crank, locale: :en)
    assert_select "a[href=?]", lure_path(@jerk, locale: :en), false
  end

  test "hub is indexable and self-canonical" do
    get lure_type_path(@crankbait, locale: :en)
    assert_select "meta[name=robots]", false
    assert_select "link[rel=canonical][href=?]", lure_type_url(@crankbait, locale: :en)
    assert_select "h1", text: /Crankbait/
  end

  test "an unpublished lure stays out of its hub" do
    hidden = Lure.create!(brand: @brand, lure_type: @crankbait, model: "Unapproved Squarebill")
    ModerationItem.create!(subject: hidden, kind: :catalog, submitter: users(:two))

    get lure_type_path(@crankbait, locale: :en)
    assert_select "a[href=?]", lure_path(hidden, locale: :en), false
  end

  test "unknown type key is not found" do
    get lure_type_path("no-such-type", locale: :en)
    assert_response :not_found
  end

  test "lure page links back to its type hub" do
    get lure_path(@crank, locale: :en)
    assert_select "a[href=?]", lure_type_path(@crankbait, locale: :en)
  end

  test "lures index links the type hubs" do
    get lures_path(locale: :en)
    assert_select "a[href=?]", lure_type_path(@crankbait, locale: :en)
    assert_select "a[href=?]", lure_type_path(@jerkbait, locale: :en)
  end
end
