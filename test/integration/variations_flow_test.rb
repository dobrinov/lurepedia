require "test_helper"

# The lure /variations JSON (consumed by the picker modal) and the moderated
# creation/editing of colors and builds.
class VariationsFlowTest < ActionDispatch::IntegrationTest
  def setup
    @type = LureType.create!(key: "jerkbait")
    @brand = Brand.create!(name: "Megabass")
    @lure = Lure.create!(brand: @brand, lure_type: @type, model: "Vision 110")
    @color = @lure.variants.create!(name: "GG Ayu", uv_glow: true)
    @build = @lure.builds.create!(name: "110 SP", depth_min_cm: 120, depth_max_cm: 180, action: :suspending)
    @member = User.create!(name: "Mia", email_address: "mia@example.com", password: "secret123", role: :member)
    @admin = User.create!(name: "Ada", email_address: "ada@example.com", password: "secret123", role: :admin)
  end

  test "variations endpoint returns colors and builds independently" do
    get lure_variation_options_path(@lure, locale: :en)
    assert_response :success
    body = JSON.parse(response.body)
    assert_equal "Megabass Vision 110", body.dig("lure", "title")
    color = body["colors"].first
    assert_equal "GG Ayu", color["name"]
    assert color["uv_glow"]
    assert_not color.key?("build_ids"), "colors no longer carry per-color build availability"
    assert_equal "110 SP", body["builds"].first["name"]
  end

  test "lure options can be scoped to a brand" do
    other = Brand.create!(name: "Lucky Craft")
    Lure.create!(brand: other, lure_type: @type, model: "Pointer 100")

    get lure_options_path(locale: :en, brand: @brand.slug, format: :json)
    assert_response :success
    labels = JSON.parse(response.body)["results"].map { |r| r["label"] }
    assert_includes labels, "Megabass Vision 110"
    assert_not_includes labels, "Lucky Craft Pointer 100"
  end

  test "catch form prefills the brand to color cascade from query params" do
    sign_in_as(@member)
    get new_catch_path(locale: :en, lure: @lure.slug, variant_id: @color.id, build_id: @build.id)
    assert_response :success
    # Brand is derived from the lure even when not passed explicitly.
    assert_select "[data-catch-picker-lure-slug-value=?]", @lure.slug
    assert_select "[data-catch-picker-selected-variant-value=?]", @color.id.to_s
    assert_select "[data-catch-picker-selected-build-value=?]", @build.id.to_s
    assert_match @brand.name, response.body
  end

  test "admin adds a color directly and it is queued for review" do
    sign_in_as(@admin)
    assert_difference -> { @lure.variants.count } => 1, -> { ModerationItem.count } => 1 do
      post variants_path(@lure, locale: :en), params: { variant: { name: "Pro Blue", uv_glow: "0" } }
    end
    assert_redirected_to edit_lure_path(@lure)
  end

  test "member suggesting a color edit files a revision and moderation item" do
    sign_in_as(@member)
    assert_difference -> { Revision.count } => 1, -> { ModerationItem.count } => 1 do
      patch variant_path(@lure, @color, locale: :en), params: { variant: { best_for: "Smallmouth · Clear" } }
    end
    # Non-admin edits are not applied until reviewed.
    assert_nil @color.reload.best_for
    assert_equal :edit, ModerationItem.last.kind.to_sym
  end

  test "admin edits a build directly" do
    sign_in_as(@admin)
    patch build_path(@lure, @build, locale: :en), params: { build: { depth_max_cm: 200 } }
    assert_equal 200, @build.reload.depth_max_cm
  end

  test "creating a color requires login" do
    post variants_path(@lure, locale: :en), params: { variant: { name: "X" } }
    assert_response :redirect
    assert_equal 1, @lure.variants.count
  end
end
