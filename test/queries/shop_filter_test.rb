require "test_helper"

class ShopFilterTest < ActiveSupport::TestCase
  def setup
    @tackle_uk = Shop.create!(name: "Angling Direct", url: "https://ad.example.com", ships_to: "GB, IE")
    @global = Shop.create!(name: "Tackle Warehouse", url: "https://tw.example.com", ships_worldwide: true)
    @local = Shop.create!(name: "Sofia Fishing", url: "https://sf.example.com", ships_to: "BG")
    user = User.create!(name: "A", email_address: "a@example.com", password: "secret123")
    Claim.create!(claimable: @global, user: user, email: "o@x.com", message: "Mine.", status: :verified)
  end

  test "no filters lists all shops" do
    assert_equal 3, ShopFilter.new({}).results.count
  end

  test "text query matches name" do
    assert_equal [ @global ], ShopFilter.new(q: "warehouse").results.to_a
  end

  test "country keeps shops delivering there, including worldwide" do
    assert_equal [ @tackle_uk, @global ], ShopFilter.new(country: "GB").results
  end

  test "worldwide only" do
    assert_equal [ @global ], ShopFilter.new(worldwide: "1").results.to_a
  end

  test "claimed only keeps verified claims" do
    assert_equal [ @global ], ShopFilter.new(claimed: "1").results.to_a
  end

  test "active pills reflect filters" do
    keys = ShopFilter.new(country: "GB", worldwide: "1", claimed: "1").active_pills.map(&:first)
    assert_equal %i[country worldwide claimed], keys
  end
end
