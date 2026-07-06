require "test_helper"

class BrandFilterTest < ActiveSupport::TestCase
  def setup
    @megabass = Brand.create!(name: "Megabass", country: "JP")
    @rapala = Brand.create!(name: "Rapala", country: "FI")
    @strike = Brand.create!(name: "Strike King", country: "US")
    user = User.create!(name: "A", email_address: "a@example.com", password: "secret123")
    Claim.create!(claimable: @megabass, user: user, email: "o@x.com", message: "Mine.", status: :verified)
    Claim.create!(claimable: @rapala, user: user, email: "o@x.com", message: "Mine too.")
    crank = LureType.create!(key: "crankbait")
    Lure.create!(brand: @rapala, lure_type: crank, model: "Shad Rap", catches_count: 3)
    Lure.create!(brand: @strike, lure_type: crank, model: "KVD 1.5")
  end

  test "no filters lists all brands alphabetically" do
    assert_equal [ @megabass, @rapala, @strike ], BrandFilter.new({}).results.to_a
  end

  test "text query matches name" do
    assert_equal [ @rapala ], BrandFilter.new(q: "rapa").results.to_a
  end

  test "filter by country" do
    assert_equal [ @megabass ], BrandFilter.new(country: "JP").results.to_a
  end

  test "claimed only keeps verified claims" do
    assert_equal [ @megabass ], BrandFilter.new(claimed: "1").results.to_a
  end

  test "proven only keeps brands with proven lures" do
    assert_equal [ @rapala ], BrandFilter.new(proven: "1").results.to_a
  end

  test "active pills reflect filters" do
    keys = BrandFilter.new(country: "JP", claimed: "1", proven: "1").active_pills.map(&:first)
    assert_equal %i[country claimed proven], keys
  end

  test "any? counts free text and filters" do
    assert BrandFilter.new(q: "rapa").any?
    assert BrandFilter.new(country: "JP").any?
    assert_not BrandFilter.new({}).any?
  end
end
