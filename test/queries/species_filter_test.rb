require "test_helper"

class SpeciesFilterTest < ActiveSupport::TestCase
  def setup
    @pike = Species.create!(key: "northern_pike", water: :fresh, catches_count: 2)
    @seabass = Species.create!(key: "european_seabass", water: :both)
    @weever = Species.create!(key: "greater_weever", water: :salt, venomous: true)
    @puffer = Species.create!(key: "pufferfish", water: :salt, poisonous: true)
  end

  test "no filters lists all species" do
    assert_equal 4, SpeciesFilter.new({}).results.count
  end

  test "text query matches names in Ruby" do
    assert_equal [ @pike ], SpeciesFilter.new(q: "pike").results
  end

  test "fresh includes fresh-and-salt species" do
    assert_equal [ @seabass, @pike ], SpeciesFilter.new(water: "fresh").results.to_a
  end

  test "salt includes fresh-and-salt species" do
    results = SpeciesFilter.new(water: "salt").results.to_a
    assert_includes results, @weever
    assert_includes results, @seabass
    assert_not_includes results, @pike
  end

  test "both narrows to true fresh-and-salt species" do
    assert_equal [ @seabass ], SpeciesFilter.new(water: "both").results.to_a
  end

  test "hazard toggles" do
    assert_equal [ @weever ], SpeciesFilter.new(venomous: "1").results.to_a
    assert_equal [ @puffer ], SpeciesFilter.new(poisonous: "1").results.to_a
  end

  test "proven only keeps species with catches" do
    assert_equal [ @pike ], SpeciesFilter.new(proven: "1").results.to_a
  end

  test "text query composes with filters" do
    assert_equal [], SpeciesFilter.new(q: "pike", water: "salt").results
  end

  test "active pills reflect filters" do
    keys = SpeciesFilter.new(water: "salt", venomous: "1", proven: "1").active_pills.map(&:first)
    assert_equal %i[water venomous proven], keys
  end
end
