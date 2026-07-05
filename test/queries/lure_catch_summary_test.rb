require "test_helper"

class LureCatchSummaryTest < ActiveSupport::TestCase
  def setup
    type = LureType.create!(key: "jerkbait")
    brand = Brand.create!(name: "Megabass")
    @lure = Lure.create!(brand: brand, lure_type: type, model: "Vision 110")
    @variant = @lure.variants.create!(name: "GG")
    @bass = Species.create!(key: "largemouth_bass")
    @pike = Species.create!(key: "northern_pike")
    @user = User.create!(name: "Ann", email_address: "ann@example.com", password: "secret123")
  end

  test "empty lure has no summary" do
    summary = LureCatchSummary.new(@lure)
    assert_not summary.any?
    assert_empty summary.species_counts
    assert_empty summary.condition_counts
  end

  test "species ranked by catch count" do
    2.times { Catch.create!(user: @user, variant: @variant, species: @pike) }
    Catch.create!(user: @user, variant: @variant, species: @bass)

    summary = LureCatchSummary.new(@lure.reload)
    assert summary.any?
    assert_equal 3, summary.total
    assert_equal [ [ @pike, 2 ], [ @bass, 1 ] ], summary.species_counts
  end

  test "condition groups rank values and omit unlogged groups" do
    2.times { Catch.create!(user: @user, variant: @variant, species: @bass, season: :spring, clarity: :clear) }
    Catch.create!(user: @user, variant: @variant, species: @bass, season: :summer)

    counts = LureCatchSummary.new(@lure).condition_counts
    assert_equal [ [ "spring", 2 ], [ "summer", 1 ] ], counts[:season]
    assert_equal [ [ "clear", 2 ] ], counts[:clarity]
    assert_not_includes counts.keys, :wind
  end

  test "caps species and per-group values" do
    5.times do |i|
      species = Species.create!(key: "species_#{i}")
      Catch.create!(user: @user, variant: @variant, species: species)
    end

    summary = LureCatchSummary.new(@lure)
    assert_equal 4, summary.species_counts.size
    assert_equal 2, summary.species_counts(limit: 2).size
  end
end
