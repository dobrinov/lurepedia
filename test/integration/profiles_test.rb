require "test_helper"

class ProfilesControllerTest < ActionDispatch::IntegrationTest
  def setup
    @owner = users(:two)
    brand = Brand.create!(name: "Rapala")
    type = LureType.create!(key: "crankbait")
    @lure = Lure.create!(brand: brand, lure_type: type, model: "DT-6")
    variant = @lure.variants.create!(name: "Firetiger")
    species = Species.create!(key: "largemouth_bass")
    @catch = Catch.create!(user: @owner, variant: variant, species: species, season: :spring, clarity: :clear)
    Favorite.create!(user: @owner, favoritable: @lure)
  end

  test "resolves a profile by slug" do
    get profile_path(@owner.slug, locale: :en)
    assert_response :success
    assert_select "h1", text: /#{@owner.name}/
  end

  test "resolves a profile by username" do
    @owner.update!(username: "marcus")
    get profile_path("marcus", locale: :en)
    assert_response :success
  end

  test "unknown handle is 404" do
    # find_by_handle! raises RecordNotFound (covered in user_test.rb); at the
    # request level this app's show_exceptions = :rescuable renders a 404.
    get profile_path("ghost", locale: :en)
    assert_response :not_found
  end

  test "profile shows the user's catches and favorites" do
    get profile_path(@owner, locale: :en)
    assert_select ".grid-catches"
    assert_select "body", text: /#{@lure.model}/
  end

  test "my/catches redirects to the owner's profile" do
    sign_in_as(@owner)
    get my_catches_path(locale: :en)
    # Signed-in users get locale-free URLs.
    assert_redirected_to profile_path(@owner)
  end

  test "my/catches requires login" do
    get my_catches_path(locale: :en)
    assert_redirected_to new_session_path(locale: :en)
  end

  test "settings shows the public profile url and accepts a username" do
    sign_in_as(@owner)
    get edit_settings_path(locale: :en)
    assert_response :success
    assert_select "input[name=?]", "user[username]"

    patch settings_path(locale: :en), params: { user: { username: "marcus-l" } }
    assert_equal "marcus-l", @owner.reload.username
  end

  test "invalid username is rejected with an error" do
    sign_in_as(@owner)
    patch settings_path(locale: :en), params: { user: { username: "no spaces" } }
    assert_response :unprocessable_entity
    assert_nil @owner.reload.username
  end
end
