require "test_helper"

# Smoke-tests that the search filter panel renders with populated dropdowns:
# async comboboxes wired to their endpoints, inline options for static enums,
# and the resolved label for an already-active filter.
class SearchFiltersTest < ActionDispatch::IntegrationTest
  test "lures index renders with populated filter dropdowns" do
    LureType.create!(key: "crankbait")
    b = Brand.create!(name: "Strike King")
    lt = LureType.first
    lure = Lure.create!(brand: b, lure_type: lt, model: "KVD 1.5")
    lure.builds.create!(name: "Standard", depth_min_cm: 0, depth_max_cm: 100)
    Species.create!(key: "largemouth_bass")

    get lures_path
    assert_response :success
    # async comboboxes wired to endpoints
    assert_select "[data-controller='async-combobox'][data-async-combobox-url-value*='options/species']"
    assert_select "[data-controller='async-combobox'][data-async-combobox-url-value*='options/brands']"
    # static enum combobox carries inline options (e.g. depth bands / lure types)
    assert_match "Crankbait", response.body
    assert_match "Shallow", response.body
  end

  test "lures index renders with active species filter showing its label" do
    LureType.create!(key: "crankbait")
    Species.create!(key: "largemouth_bass")
    get lures_path(species: Species.first.slug)
    assert_response :success
    assert_match "Largemouth Bass", response.body
  end

  test "weight filter is labelled in grams for metric viewers" do
    get lures_path
    assert_response :success
    assert_match "#{I18n.t('lure.weight')} (#{I18n.t('units.g')})", response.body
    assert_select "input[name='weight_unit']", count: 0
  end

  test "weight filter follows an imperial viewer's unit preference" do
    user = User.create!(name: "Angler", email_address: "oz@example.com", password: "secret123", weight_units: :imperial)
    sign_in_as(user)

    get lures_path
    assert_response :success
    assert_match "#{I18n.t('lure.weight')} (#{I18n.t('units.oz')})", response.body
    assert_select "input[type='hidden'][name='weight_unit'][value='oz']"
  end

  test "weight inputs keep the unit the URL was built with over the viewer's preference" do
    get lures_path(weight_min: "1", weight_unit: "oz")
    assert_response :success
    assert_match "#{I18n.t('lure.weight')} (#{I18n.t('units.oz')})", response.body
    assert_select "input[name='weight_min'][value='1']"
    # the active pill reads in the entered unit too
    assert_select ".filter-pill", text: /1 oz/
  end

  test "a search with no matches offers to clear filters and add the missing lure" do
    get lures_path(q: "zzz-no-such-lure-anywhere")
    assert_response :success
    assert_select ".empty-state h3", text: I18n.t("lure.no_matches")
    assert_select ".empty-state a", text: I18n.t("search.clear_all")
    assert_select ".empty-state a", text: I18n.t("lure.add")
  end

  test "an empty catalog shows the empty state, not the no-matches filter state" do
    Lure.destroy_all
    get lures_path
    assert_response :success
    assert_select ".empty-state h3", text: I18n.t("lure.empty_title")
    assert_no_match(/#{Regexp.escape(I18n.t("lure.no_matches"))}/, response.body)
  end
end
