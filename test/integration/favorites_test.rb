require "test_helper"

class FavoritesControllerTest < ActionDispatch::IntegrationTest
  def setup
    @user = users(:two)
    brand = Brand.create!(name: "Rapala")
    type = LureType.create!(key: "crankbait")
    @lure = Lure.create!(brand: brand, lure_type: type, model: "DT-6")
  end

  test "signed-out user cannot favorite" do
    post favorites_path(favoritable_type: "Lure", favoritable_id: @lure.id)
    assert_redirected_to new_session_path
  end

  test "signed-in user favorites and unfavorites a lure" do
    sign_in_as(@user)

    assert_difference -> { @user.favorites.count }, 1 do
      post favorites_path(favoritable_type: "Lure", favoritable_id: @lure.id)
    end
    assert @lure.reload.favorited_by?(@user)

    assert_difference -> { @user.favorites.count }, -1 do
      delete favorites_path(favoritable_type: "Lure", favoritable_id: @lure.id)
    end
    assert_not @lure.reload.favorited_by?(@user)
  end

  test "favoriting twice does not error or duplicate" do
    sign_in_as(@user)
    post favorites_path(favoritable_type: "Lure", favoritable_id: @lure.id)
    post favorites_path(favoritable_type: "Lure", favoritable_id: @lure.id)
    assert_equal 1, @user.favorites.count
  end

  test "rejects an unsupported favoritable type" do
    sign_in_as(@user)
    post favorites_path(favoritable_type: "User", favoritable_id: @user.id)
    assert_response :unprocessable_entity
  end

  test "lure show page renders the favorite button for signed-in users" do
    sign_in_as(@user)
    get lure_path(@lure, locale: :en)
    assert_response :success
    assert_select "form[action=?]", favorites_path(favoritable_type: "Lure", favoritable_id: @lure.id)
  end

  test "lure show page shows sign-in prompt to guests" do
    get lure_path(@lure, locale: :en)
    assert_select "a[href=?]", new_session_path, text: I18n.t("favorites.sign_in_to_favorite")
  end
end
