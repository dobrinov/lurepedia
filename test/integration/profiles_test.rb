require "test_helper"

class ProfilesControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  def setup
    @owner = users(:two)
    brand = Brand.create!(name: "Rapala")
    type = LureType.create!(key: "crankbait")
    @lure = Lure.create!(brand: brand, lure_type: type, model: "DT-6")
    variant = @lure.variants.create!(name: "Firetiger")
    species = Species.create!(key: "largemouth_bass")
    @catch = create_catch(user: @owner, variant: variant, species: species, season: :spring, clarity: :clear)
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

  test "favorites tab lists favorited records" do
    get profile_path(@owner, tab: "favorites", locale: :en)
    assert_response :success
    assert_select "body", text: /#{@lure.model}/
  end

  test "contributions tab lists the user's revisions" do
    @lure.revisions.create!(user: @owner, summary: "Suggested an edit to DT-6", changeset: { "model" => [ "DT-6", "DT-7" ] })
    get profile_path(@owner, tab: "contributions", locale: :en)
    assert_response :success
    assert_select "body", text: /Suggested an edit to DT-6/
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
    @owner.reload
    assert_redirected_to profile_path(@owner, tab: "settings", locale: @owner.locale)
    assert_equal "marcus-l", @owner.username
  end

  test "owner settings tab merges account and preference fields" do
    sign_in_as(@owner)
    get profile_path(@owner, tab: "settings", locale: :en)
    assert_response :success
    assert_select "input[name=?]", "user[username]"
    assert_select "select[name=?]", "user[length_units]"
  end

  test "non-owner cannot reach the settings tab and falls back to catches" do
    get profile_path(@owner, tab: "settings", locale: :en)
    assert_response :success
    assert_select "input[name=?]", "user[username]", count: 0
    assert_select ".grid-catches"
  end

  test "saving from the sidebar returns to the originating tab" do
    sign_in_as(@owner)
    patch settings_path(locale: :en), params: { return_tab: "contributions", user: { depth_units: "metric" } }
    @owner.reload
    assert_redirected_to profile_path(@owner, tab: "contributions", locale: @owner.locale)
    assert @owner.depth_metric?
  end

  test "owner can change the avatar from the sidebar" do
    sign_in_as(@owner)
    get profile_path(@owner, tab: "catches", locale: :en)
    assert_select "form .profile-photo-overlay"
    assert_select "form input[type=file][name=?]", "user[avatar]"
  end

  test "invalid username is rejected with an error" do
    sign_in_as(@owner)
    patch settings_path(locale: :en), params: { user: { username: "no spaces" } }
    assert_response :unprocessable_entity
    assert_nil @owner.reload.username
  end

  test "uploading an avatar attaches it and shows it on the profile" do
    sign_in_as(@owner)
    avatar = fixture_file_upload("avatar.png", "image/png")
    patch settings_path(locale: :en), params: { user: { avatar: avatar } }
    assert @owner.reload.avatar.attached?

    get profile_path(@owner, locale: :en)
    assert_select ".profile-photo-edit img"
  end

  test "rejects a non-image avatar" do
    sign_in_as(@owner)
    bogus = fixture_file_upload("not_an_image.txt", "text/plain")
    patch settings_path(locale: :en), params: { user: { avatar: bogus } }
    assert_response :unprocessable_entity
    assert_not @owner.reload.avatar.attached?
  end

  test "removing an avatar purges it" do
    sign_in_as(@owner)
    @owner.avatar.attach(fixture_file_upload("avatar.png", "image/png"))
    assert @owner.avatar.attached?

    perform_enqueued_jobs do
      patch settings_path(locale: :en), params: { user: { remove_avatar: "1" } }
    end
    assert_not @owner.reload.avatar.attached?
  end
end
