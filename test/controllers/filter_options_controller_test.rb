require "test_helper"

class FilterOptionsControllerTest < ActionDispatch::IntegrationTest
  test "brands first page returns a full page and a next page pointer" do
    25.times { |i| Brand.create!(name: format("Brand %02d", i)) }

    get brand_options_path(format: :json)
    assert_response :success
    body = JSON.parse(response.body)
    assert_equal 20, body["results"].size
    assert_equal 2, body["next_page"]
    assert body["results"].all? { |o| o["value"].present? && o["label"].present? }
  end

  test "brands last page has no next page pointer" do
    25.times { |i| Brand.create!(name: format("Brand %02d", i)) }

    get brand_options_path(format: :json, page: 2)
    body = JSON.parse(response.body)
    assert_equal 5, body["results"].size
    assert_nil body["next_page"]
  end

  test "brands search filters by name" do
    Brand.create!(name: "Megabass")
    Brand.create!(name: "Strike King")

    get brand_options_path(format: :json, q: "mega")
    body = JSON.parse(response.body)
    assert_equal [ "Megabass" ], body["results"].map { |o| o["label"] }
  end

  test "species first page paginates" do
    25.times { |i| Species.create!(key: "fish_#{format('%02d', i)}") }

    get species_options_path(format: :json)
    body = JSON.parse(response.body)
    assert_equal 20, body["results"].size
    assert_equal 2, body["next_page"]

    get species_options_path(format: :json, page: 2)
    body = JSON.parse(response.body)
    assert_equal 5, body["results"].size
    assert_nil body["next_page"]
  end

  test "species search matches localized common name" do
    Species.create!(key: "largemouth_bass")
    Species.create!(key: "northern_pike")

    get species_options_path(format: :json, q: "bass")
    body = JSON.parse(response.body)
    labels = body["results"].map { |o| o["label"] }
    assert_includes labels, "Largemouth Bass"
    assert_not_includes labels, "Northern Pike"
  end
end
