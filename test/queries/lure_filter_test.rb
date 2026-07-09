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

  test "water salt matches salt and both builds" do
    assert_equal [ @salt ], LureFilter.new(water: "salt").results.to_a
  end

  test "water fresh matches fresh builds and excludes salt-only builds" do
    fresh = Lure.create!(brand: @sk, lure_type: @crank, model: "Fresh One")
    fresh.builds.create!(name: "FW", water: :fresh)
    results = LureFilter.new(water: "fresh").results.to_a
    assert_includes results, fresh
    assert_not_includes results, @salt
  end

  test "active pills reflect filters" do
    f = LureFilter.new(type: "crankbait", water: "salt")
    keys = f.active_pills.map(&:first)
    assert_includes keys, :type
    assert_includes keys, :water
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

  test "filter by length range matches any build in range" do
    small = Lure.create!(brand: @sk, lure_type: @jerk, model: "Squirt 65")
    small.builds.create!(name: "65", length_mm: 65)
    big = Lure.create!(brand: @sk, lure_type: @jerk, model: "Magnum 180")
    big.builds.create!(name: "180", length_mm: 180)
    both = Lure.create!(brand: @sk, lure_type: @jerk, model: "Family")
    both.builds.create!(name: "S", length_mm: 70)
    both.builds.create!(name: "L", length_mm: 160)

    assert_equal [ big, both ].sort_by(&:id), LureFilter.new(length_min: "100").results.sort_by(&:id)
    assert_equal [ small, both ].sort_by(&:id), LureFilter.new(length_max: "90").results.sort_by(&:id)
    assert_equal [ both ], LureFilter.new(length_min: "150", length_max: "170").results.to_a
  end

  test "filter by weight range" do
    light = Lure.create!(brand: @sk, lure_type: @jerk, model: "Feather")
    light.builds.create!(name: "F", weight_g: 5.5)
    heavy = Lure.create!(brand: @sk, lure_type: @jerk, model: "Brick")
    heavy.builds.create!(name: "B", weight_g: 42)

    assert_equal [ light ], LureFilter.new(weight_max: "10").results.to_a
    assert_equal [ heavy ], LureFilter.new(weight_min: "10").results.to_a
    assert_equal [], LureFilter.new(weight_min: "50", weight_max: "60").results.to_a
  end

  test "weight range in ounces converts to grams, rounding to catch nominal weights" do
    oneoz = Lure.create!(brand: @sk, lure_type: @jerk, model: "Nominal Ounce")
    oneoz.builds.create!(name: "1oz", weight_g: 28) # catalogued as "28 g", sold as "1 oz"
    heavy = Lure.create!(brand: @sk, lure_type: @jerk, model: "Two Ounce")
    heavy.builds.create!(name: "2oz", weight_g: 57)

    assert_equal [ oneoz, heavy ].sort_by(&:id), LureFilter.new(weight_min: "1", weight_unit: "oz").results.sort_by(&:id)
    assert_equal [ oneoz ], LureFilter.new(weight_max: "1", weight_unit: "oz").results.to_a
    assert_equal [ heavy ], LureFilter.new(weight_min: "1.5", weight_unit: "oz").results.to_a
  end

  test "unknown weight units fall back to grams" do
    light = Lure.create!(brand: @sk, lure_type: @jerk, model: "Feather")
    light.builds.create!(name: "F", weight_g: 5.5)
    assert_equal [ light ], LureFilter.new(weight_max: "10", weight_unit: "stone").results.to_a
  end

  test "builds without the spec never match a range filter" do
    unspecced = Lure.create!(brand: @sk, lure_type: @jerk, model: "Mystery")
    unspecced.builds.create!(name: "?")
    assert_not_includes LureFilter.new(length_min: "0").results.to_a, unspecced
    assert_not_includes LureFilter.new(weight_max: "1000").results.to_a, unspecced
  end

  test "range filters ignore non-numeric values" do
    assert_equal LureFilter.new({}).results.to_a, LureFilter.new(length_min: "abc", weight_max: "").results.to_a
    assert_empty LureFilter.new(length_min: "abc").active_pills
  end

  test "range pills label the bounds and clear both params" do
    pills = LureFilter.new(length_min: "70", length_max: "120", weight_min: "10.5").active_pills.to_h
    assert_equal "70–120 mm", pills[:length]
    assert_equal "≥ 10.5 g", pills[:weight]
    assert_equal %w[ length_min length_max ], LureFilter.pill_params(:length)
    assert_equal [ "type" ], LureFilter.pill_params(:type)
  end

  test "weight pill shows the entered unit and its params include the unit" do
    pills = LureFilter.new(weight_min: "0.5", weight_max: "1.5", weight_unit: "oz").active_pills.to_h
    assert_equal "0.5–1.5 oz", pills[:weight]
    assert_equal %w[ weight_min weight_max weight_unit ], LureFilter.pill_params(:weight)
  end

  test "filter by hook type matches any build with that hook" do
    singles = Lure.create!(brand: @sk, lure_type: @jerk, model: "Single Rig")
    singles.builds.create!(name: "S", hook_type: :single)
    trebles = Lure.create!(brand: @sk, lure_type: @jerk, model: "Treble Rig")
    trebles.builds.create!(name: "T", hook_type: :treble)
    mixed = Lure.create!(brand: @sk, lure_type: @jerk, model: "Mixed Rig")
    mixed.builds.create!(name: "M1", hook_type: :single)
    mixed.builds.create!(name: "M2", hook_type: :treble)

    assert_equal [ singles, mixed ].sort_by(&:id), LureFilter.new(hook: "single").results.sort_by(&:id)
    assert_equal [ trebles, mixed ].sort_by(&:id), LureFilter.new(hook: "treble").results.sort_by(&:id)
  end

  test "hook ignores unknown values" do
    assert_equal LureFilter.new({}).results.to_a, LureFilter.new(hook: "quadruple").results.to_a
  end

  test "hook appears in active pills" do
    keys = LureFilter.new(hook: "single").active_pills.map(&:first)
    assert_includes keys, :hook
  end

  test "filter by material" do
    @kvd.update!(material: :plastic)
    @vision.update!(material: :wood)
    assert_equal [ @vision ], LureFilter.new(material: "wood").results.to_a
    assert_equal [ @kvd ], LureFilter.new(material: "plastic").results.to_a
  end

  test "material ignores unknown values" do
    assert_equal LureFilter.new({}).results.to_a, LureFilter.new(material: "titanium").results.to_a
  end

  test "material appears in active pills" do
    @kvd.update!(material: :metal)
    keys = LureFilter.new(material: "metal").active_pills.map(&:first)
    assert_includes keys, :material
  end

  test "glow and uv filter by color finish and are independent" do
    glow_lure = Lure.create!(brand: @sk, lure_type: @jerk, model: "Night Glow")
    glow_lure.variants.create!(name: "Phosphor", glow: true)
    uv_lure = Lure.create!(brand: @sk, lure_type: @jerk, model: "UV Special")
    uv_lure.variants.create!(name: "Reactive", uv: true)

    assert_equal [ glow_lure ], LureFilter.new(glow: "1").results.to_a
    assert_equal [ uv_lure ], LureFilter.new(uv: "1").results.to_a
  end

  test "a lure matches when any of its colors carries the finish" do
    lure = Lure.create!(brand: @sk, lure_type: @jerk, model: "Mixed Bag")
    lure.variants.create!(name: "Plain")
    lure.variants.create!(name: "Glowy", glow: true)
    assert_includes LureFilter.new(glow: "1").results.to_a, lure
  end

  test "glow and uv appear in active pills" do
    keys = LureFilter.new(glow: "1", uv: "1").active_pills.map(&:first)
    assert_includes keys, :glow
    assert_includes keys, :uv
  end
end
