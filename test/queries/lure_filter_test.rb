require "test_helper"

class LureFilterTest < ActiveSupport::TestCase
  def setup
    @crank = LureType.create!(key: "crankbait")
    @jerk = LureType.create!(key: "jerkbait")
    @sk = Brand.create!(name: "Strike King")
    @mb = Brand.create!(name: "Megabass")
    @kvd = Lure.create!(brand: @sk, lure_type: @crank, model: "KVD 1.5", catches_count: 5)
    @vision = Lure.create!(brand: @mb, lure_type: @jerk, model: "Vision 110", catches_count: 9)
    @salt = Lure.create!(brand: @mb, lure_type: @jerk, model: "Saltwater Special")
    @salt.builds.create!(name: "SW", water: :salt)
    @bass = Species.create!(key: "largemouth_bass")
    user = User.create!(name: "A", email_address: "a@example.com", password: "secret123")
    variant = @vision.variants.create!(name: "GG")
    create_catch(user: user, variant: variant, species: @bass, season: :spring)
  end

  test "default sort by most recently edited" do
    @kvd.update!(model: "KVD 1.5 Pro")
    assert_equal [ @kvd, @salt, @vision ], LureFilter.new({}).results.to_a
  end

  test "proven sort by catch count desc" do
    assert_equal [ @vision, @kvd, @salt ], LureFilter.new(sort: "proven").results.to_a
  end

  test "filter by type" do
    assert_equal [ @kvd ], LureFilter.new(type: "crankbait").results.to_a
  end

  test "filter by brand slug" do
    results = LureFilter.new(brand: @mb.slug).results.to_a
    assert_includes results, @vision
    assert_not_includes results, @kvd
  end

  test "text query matches model and brand" do
    assert_equal [ @kvd ], LureFilter.new(q: "kvd").results.to_a
    assert_includes LureFilter.new(q: "megabass").results.to_a, @vision
  end

  test "filter by species via catches" do
    assert_equal [ @vision ], LureFilter.new(species: @bass.slug).results.to_a
  end

  test "saltwater only" do
    assert_equal [ @salt ], LureFilter.new(saltwater: "1").results.to_a
  end

  test "active pills reflect filters" do
    f = LureFilter.new(type: "crankbait", saltwater: "1")
    keys = f.active_pills.map(&:first)
    assert_includes keys, :type
    assert_includes keys, :saltwater
  end

  test "filter by lure_action" do
    suspending = Lure.create!(brand: @sk, lure_type: @jerk, model: "Pointer")
    suspending.builds.create!(name: "SP", action: :suspending)
    results = LureFilter.new(lure_action: "suspending").results.to_a
    assert_equal [ suspending ], results
  end

  test "lure_action ignores unknown values" do
    assert_equal LureFilter.new({}).results.to_a, LureFilter.new(lure_action: "bogus").results.to_a
  end

  test "lure_action appears in active pills" do
    keys = LureFilter.new(lure_action: "suspending").active_pills.map(&:first)
    assert_includes keys, :lure_action
  end

  test "filter by depth band overlaps the lure depth range" do
    shallow = Lure.create!(brand: @sk, lure_type: @crank, model: "Shallow Squarebill")
    shallow.builds.create!(name: "S", depth_min_cm: 0, depth_max_cm: 100)
    mid     = Lure.create!(brand: @sk, lure_type: @crank, model: "Medium Diver")
    mid.builds.create!(name: "M", depth_min_cm: 200, depth_max_cm: 400)
    deep    = Lure.create!(brand: @sk, lure_type: @crank, model: "Deep Diver")
    deep.builds.create!(name: "D", depth_min_cm: 600, depth_max_cm: 900)

    assert_equal [ shallow ], LureFilter.new(depth: "shallow").results.to_a
    assert_equal [ mid ], LureFilter.new(depth: "mid").results.to_a
    assert_equal [ deep ], LureFilter.new(depth: "deep").results.to_a
  end

  test "depth ignores unknown bands and appears in active pills" do
    assert_equal LureFilter.new({}).results.to_a, LureFilter.new(depth: "bogus").results.to_a
    assert_includes LureFilter.new(depth: "shallow").active_pills.map(&:first), :depth
  end
end
