require "test_helper"

class FavoritesTest < ActiveSupport::TestCase
  def setup
    @user = users(:two)
    @brand = Brand.create!(name: "Rapala")
    @type = LureType.create!(key: "crankbait")
    @lure = Lure.create!(brand: @brand, lure_type: @type, model: "DT-6")
    @species = Species.create!(key: "northern_pike")
    @shop = Shop.create!(name: "Tackle Town", url: "tackletown.com")
  end

  test "user can favorite a lure, species and shop" do
    Favorite.create!(user: @user, favoritable: @lure)
    Favorite.create!(user: @user, favoritable: @species)
    Favorite.create!(user: @user, favoritable: @shop)
    assert_equal 3, @user.favorites.count
  end

  test "favorites are unique per user and target" do
    Favorite.create!(user: @user, favoritable: @lure)
    dup = Favorite.new(user: @user, favoritable: @lure)
    assert_not dup.valid?
  end

  test "favorited_by? reflects state" do
    assert_not @lure.favorited_by?(@user)
    Favorite.create!(user: @user, favoritable: @lure)
    assert @lure.reload.favorited_by?(@user)
    assert_not @lure.favorited_by?(nil)
  end

  test "destroying a favoritable removes its favorites" do
    Favorite.create!(user: @user, favoritable: @lure)
    @lure.destroy
    assert_equal 0, Favorite.where(favoritable_type: "Lure").count
  end
end
