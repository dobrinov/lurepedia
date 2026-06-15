require "test_helper"

class LeaderboardQueryTest < ActiveSupport::TestCase
  def setup
    type = LureType.create!(key: "jerkbait")
    brand = Brand.create!(name: "Megabass")
    lure = Lure.create!(brand: brand, lure_type: type, model: "Vision 110")
    @variant = lure.variants.create!(name: "GG")
    @bass = Species.create!(key: "largemouth_bass")
    @pike = Species.create!(key: "northern_pike")

    @ann = User.create!(name: "Ann", email_address: "ann@example.com", password: "secret123")
    @bob = User.create!(name: "Bob", email_address: "bob@example.com", password: "secret123")

    # Ann: 3 bass catches, total 10 upvotes, best length 50cm
    3.times { |i| Catch.create!(user: @ann, variant: @variant, species: @bass, length_cm: 30 + i * 10, upvotes_count: i == 0 ? 10 : 0) }
    # Bob: 1 bass + 1 pike, 5 upvotes, best length 80cm
    Catch.create!(user: @bob, variant: @variant, species: @bass, length_cm: 80, upvotes_count: 5)
    Catch.create!(user: @bob, variant: @variant, species: @pike, length_cm: 40)
  end

  test "ranks by catches by default" do
    rows = LeaderboardQuery.new.rows
    assert_equal @ann, rows.first.user
    assert_equal 3, rows.first.catches
    assert_equal 2, rows.last.species_count
  end

  test "ranks by upvotes" do
    rows = LeaderboardQuery.new(metric: :upvotes).rows
    assert_equal @ann, rows.first.user
    assert_equal 10, rows.first.upvotes
  end

  test "ranks by length (personal best)" do
    rows = LeaderboardQuery.new(metric: :length).rows
    assert_equal @bob, rows.first.user
    assert_equal 80, rows.first.best_length_cm
  end

  test "species filter restricts and re-ranks" do
    rows = LeaderboardQuery.new(species: @pike).rows
    assert_equal 1, rows.size
    assert_equal @bob, rows.first.user
  end
end
