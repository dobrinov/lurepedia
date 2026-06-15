require "test_helper"

class LureFilterTest < ActiveSupport::TestCase
  def setup
    @crank = LureType.create!(key: "crankbait")
    @jerk = LureType.create!(key: "jerkbait")
    @sk = Brand.create!(name: "Strike King")
    @mb = Brand.create!(name: "Megabass")
    @kvd = Lure.create!(brand: @sk, lure_type: @crank, model: "KVD 1.5", catches_count: 5)
    @vision = Lure.create!(brand: @mb, lure_type: @jerk, model: "Vision 110", catches_count: 9)
    @salt = Lure.create!(brand: @mb, lure_type: @jerk, model: "Saltwater Special", water: :salt)
    @bass = Species.create!(key: "largemouth_bass")
    user = User.create!(name: "A", email_address: "a@example.com", password: "secret123")
    variant = @vision.variants.create!(name: "GG")
    Catch.create!(user: user, variant: variant, species: @bass, season: :spring)
  end

  test "default sort by catch count desc" do
    assert_equal [@vision, @kvd, @salt], LureFilter.new({}).results.to_a
  end

  test "filter by type" do
    assert_equal [@kvd], LureFilter.new(type: "crankbait").results.to_a
  end

  test "filter by brand slug" do
    results = LureFilter.new(brand: @mb.slug).results.to_a
    assert_includes results, @vision
    assert_not_includes results, @kvd
  end

  test "text query matches model and brand" do
    assert_equal [@kvd], LureFilter.new(q: "kvd").results.to_a
    assert_includes LureFilter.new(q: "megabass").results.to_a, @vision
  end

  test "filter by species via catches" do
    assert_equal [@vision], LureFilter.new(species: @bass.slug).results.to_a
  end

  test "saltwater only" do
    assert_equal [@salt], LureFilter.new(saltwater: "1").results.to_a
  end

  test "active pills reflect filters" do
    f = LureFilter.new(type: "crankbait", saltwater: "1")
    keys = f.active_pills.map(&:first)
    assert_includes keys, :type
    assert_includes keys, :saltwater
  end
end
