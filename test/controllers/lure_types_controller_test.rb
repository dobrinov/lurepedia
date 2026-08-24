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

  test "a deep hub renders numbered pages with an ellipsis and links a nearby page directly" do
    # 12 per page: 80 lures is 7 pages, enough to force a gap (window 2 from
    # page 1 covers 1-3, leaving 4-6 collapsed before page 7).
    80.times { |n| Lure.create!(brand: @brand, lure_type: @crankbait, model: "Model #{n}") }

    get lure_type_path(@crankbait, locale: :en)
    assert_select ".pager .current", text: "1"
    assert_select ".pager-ellipsis"
    assert_select ".pager a[href=?]", lure_type_path(@crankbait, locale: :en, page: 7)
    # The old jump-to-page form stays: numbered links cover nearby pages, but
    # a one-step jump to an arbitrary page is still faster than clicking through.
    assert_select ".pager-jump input[name=page]"
  end
end
