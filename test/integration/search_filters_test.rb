require "test_helper"

# Smoke-tests that the search filter panel renders with populated dropdowns:
# async comboboxes wired to their endpoints, inline options for static enums,
# and the resolved label for an already-active filter.
class SearchFiltersTest < ActionDispatch::IntegrationTest
  test "lures index renders with populated filter dropdowns" do
    LureType.create!(key: "crankbait")
    b = Brand.create!(name: "Strike King")
    lt = LureType.first
    Lure.create!(brand: b, lure_type: lt, model: "KVD 1.5", depth_min_cm: 0, depth_max_cm: 100)
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
end
