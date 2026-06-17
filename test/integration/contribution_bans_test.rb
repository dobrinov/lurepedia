require "test_helper"

class ContributionBansTest < ActionDispatch::IntegrationTest
  def setup
    @user = users(:two)
    @admin = users(:one)
    @brand = Brand.create!(name: "Rapala")
    @type = LureType.create!(key: "crankbait")
    @lure = Lure.create!(brand: @brand, lure_type: @type, model: "DT-6")
    @variant = @lure.variants.create!(name: "Firetiger")
    @species = Species.create!(key: "largemouth_bass")
  end

  def ban!(capabilities)
    Ban.create!(user: @user, issued_by: @admin, reason: "testing", capabilities: capabilities)
  end

  test "banned-from-catches user is blocked from creating a catch" do
    ban!(%w[catches])
    sign_in_as(@user)
    assert_no_difference -> { Catch.count } do
      post catches_path(locale: :en), params: { catch: { variant_id: @variant.id, species_id: @species.id, season: "spring" } }
    end
    # Signed-in users get locale-free URLs.
    assert_redirected_to profile_path(@user)
  end

  test "banned-from-favorites user is blocked from favoriting" do
    ban!(%w[favorites])
    sign_in_as(@user)
    assert_no_difference -> { Favorite.count } do
      post favorites_path(locale: :en, favoritable_type: "Lure", favoritable_id: @lure.id)
    end
  end

  test "unbanned capability still works" do
    ban!(%w[catalog])
    sign_in_as(@user)
    assert_difference -> { Favorite.count }, 1 do
      post favorites_path(locale: :en, favoritable_type: "Lure", favoritable_id: @lure.id)
    end
  end

  test "can_contribute? helper reflects the ban" do
    ban!(%w[favorites])
    sign_in_as(@user)
    get lure_path(@lure, locale: :en)
    assert_response :success
    assert_select "form[action*=?]", "favorites", count: 0
  end

  test "banned user sees a persistent ban notice with reason" do
    Ban.create!(user: @user, issued_by: @admin, reason: "Repeated spam", capabilities: %w[catalog catches], expires_at: 3.days.from_now)
    sign_in_as(@user)
    get lure_path(@lure, locale: :en)
    assert_select ".ban-notice", text: /Repeated spam/
  end

  test "unbanned user sees no ban notice" do
    sign_in_as(@user)
    get lure_path(@lure, locale: :en)
    assert_select ".ban-notice", count: 0
  end
end
