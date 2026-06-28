require "test_helper"

# Covers the two-axis variant model: colors (variants) × builds, the default
# color, and the per-build catch counter.
class TwoAxisVariantTest < ActiveSupport::TestCase
  def setup
    @type = LureType.create!(key: "jerkbait")
    @brand = Brand.create!(name: "Megabass")
    @lure = Lure.create!(brand: @brand, lure_type: @type, model: "Vision 110")
    @color_a = @lure.variants.create!(name: "GG Ayu")
    @color_b = @lure.variants.create!(name: "Pro Blue")
    @build = @lure.builds.create!(name: "110 SP", depth_min_cm: 120, depth_max_cm: 180, action: :suspending)
    @species = Species.create!(key: "largemouth_bass")
    @user = User.create!(name: "Ann", email_address: "ann@example.com", password: "secret123")
  end

  test "primary_variant falls back to the first-added color" do
    assert_nil @lure.default_variant, "no explicit pick yet"
    assert_equal @color_a, @lure.primary_variant
  end

  test "primary_variant honours an explicit choice" do
    @lure.update!(default_variant: @color_b)
    assert_equal @color_b, @lure.reload.default_variant
    assert_equal @color_b, @lure.primary_variant
    assert @color_b.default?
    assert_not @color_a.default?
  end

  test "depth range spans the lure's builds" do
    @lure.builds.create!(name: "Magnum", depth_min_cm: 190, depth_max_cm: 250, action: :sinking)
    assert_equal({ min_cm: 120, max_cm: 250 }, @lure.reload.depth_range)
  end

  test "dominant action is the most common buoyancy across builds" do
    @lure.builds.create!(name: "F", action: :floating)
    @lure.builds.create!(name: "SP2", action: :suspending)
    assert_equal "suspending", @lure.dominant_action
  end

  test "catch bumps the build counter and reaches the lure" do
    catch = Catch.create!(user: @user, variant: @color_a, build: @build, species: @species)
    assert_equal 1, @build.reload.catches_count
    assert_equal 1, @color_a.reload.catches_count
    assert_equal @lure, catch.lure
    catch.destroy
    assert_equal 0, @build.reload.catches_count
  end

  test "a catch may omit a build" do
    catch = Catch.new(user: @user, variant: @color_a, species: @species)
    assert catch.valid?, catch.errors.full_messages.to_sentence
  end

  test "a catch rejects a build from a different lure" do
    other_lure = Lure.create!(brand: @brand, lure_type: @type, model: "Vision 95")
    other_build = other_lure.builds.create!(name: "95 SP")
    catch = Catch.new(user: @user, variant: @color_a, build: other_build, species: @species)

    assert_not catch.valid?
    assert catch.errors[:build].any?
  end
end
