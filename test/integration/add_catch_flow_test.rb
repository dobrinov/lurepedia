require "test_helper"

# The path from a lure page to a logged catch. Signed-out visitors are the ones
# arriving from search, so the "Add a catch" affordances link straight at the
# prefilled form and let require_login bounce them through sign-in — linking at
# the sign-in page instead would drop the lure/color/build and land them on the
# homepage with nothing to come back to.
#
# The form's color and build selects are filled in by the catch-picker Stimulus
# controller, so the server-side contract for the prefill is the data-* values
# it reads, not <option selected>.
class AddCatchFlowTest < ActionDispatch::IntegrationTest
  def setup
    @type = LureType.create!(key: "topwater")
    @brand = Brand.create!(name: "Molix")
    @lure = Lure.create!(brand: @brand, lure_type: @type, model: "Water Slash")
    @color = @lure.variants.create!(name: "Banana")
    @build = @lure.builds.create!(name: "18cm-75g", length_mm: 180, weight_g: 75)
    @member = User.create!(name: "Ann", email_address: "ann@example.com", password: "secret123", role: :member)
  end

  test "signed-out builds table links each row at the catch form, not sign-in" do
    get lure_path(@lure, locale: :en)   # defaults to the variations tab
    assert_response :success

    # Signed out, this row used to link at new_session_path and drop the prefill.
    assert_select "a[href=?]",
      new_catch_path(locale: :en, lure: @lure.slug, variant_id: @color.id, build_id: @build.id)
  end

  test "signed-out empty state links at the catch form for the lure" do
    get lure_path(@lure, locale: :en, tab: "caught")
    assert_response :success

    assert_select "a[href=?]", new_catch_path(locale: :en, lure: @lure.slug)
  end

  test "signing in returns the visitor to the prefilled catch form" do
    target = new_catch_path(locale: :en, lure: @lure.slug, variant_id: @color.id, build_id: @build.id)

    get target
    assert_redirected_to new_session_path(locale: :en)

    post session_path(locale: :en), params: { email_address: @member.email_address, password: "secret123" }
    assert_redirected_to target

    follow_redirect!
    assert_response :success
    # Color and build survived the round trip, so only the species is left to pick.
    assert_select "[data-catch-picker-lure-slug-value=?]", @lure.slug
    assert_select "[data-catch-picker-selected-variant-value=?]", @color.id.to_s
    assert_select "[data-catch-picker-selected-build-value=?]", @build.id.to_s
  end

  test "a signed-in member gets the prefilled form directly" do
    sign_in_as @member

    get new_catch_path(locale: :en, lure: @lure.slug, variant_id: @color.id, build_id: @build.id)
    assert_response :success
    assert_select "[data-catch-picker-selected-variant-value=?]", @color.id.to_s
    assert_select "[data-catch-picker-selected-build-value=?]", @build.id.to_s
  end
end
