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

  test "variations endpoint ships null build_ids for unknown colors and the sorted subset for confirmed ones" do
    second = @lure.builds.create!(name: "110 F")
    confirmed = @lure.variants.create!(name: "Pro Blue")
    VariantBuild.create!(variant: confirmed, build: second)
    VariantBuild.create!(variant: confirmed, build: @build)

    get lure_variation_options_path(@lure, locale: :en)
    assert_response :success
    body = JSON.parse(response.body)
    assert_equal "Megabass Vision 110", body.dig("lure", "title")

    unknown_color, confirmed_color = body["colors"].partition { |c| c["name"] == "GG Ayu" }.map(&:first)
    assert unknown_color["uv_glow"]
    assert_nil unknown_color["build_ids"], "unknown availability is open world"
    assert_equal [ @build.id, second.id ].sort, confirmed_color["build_ids"]
    assert_equal "110 SP", body["builds"].first["name"]
  end

  test "lure page narrows a confirmed color's builds table and captions it; unknown colors show every build" do
    second = @lure.builds.create!(name: "110 F")
    confirmed = @lure.variants.create!(name: "Pro Blue")
    VariantBuild.create!(variant: confirmed, build: @build)

    get lure_path(@lure, locale: :en)
    assert_response :success

    assert_select ".variation-table[data-color-id='#{confirmed.id}']" do
      assert_select "tbody tr", count: 1
      assert_select "td", text: "110 SP"
      assert_select "p", text: /1 of 2/
    end
    assert_select ".variation-table[data-color-id='#{@color.id}']" do
      assert_select "tbody tr", count: 2
      assert_select "p", text: /of 2/, count: 0
    end
  end

  test "a moderation-hidden build stays out of every color's table, even when confirmed" do
    hidden = @lure.builds.create!(name: "110 Prototype")
    ModerationItem.create!(subject: hidden, kind: :catalog, submitter: @member)
    confirmed = @lure.variants.create!(name: "Pro Blue")
    VariantBuild.create!(variant: confirmed, build: hidden)
    VariantBuild.create!(variant: confirmed, build: @build)

    get lure_path(@lure, locale: :en)
    assert_response :success
    assert_select ".variation-table[data-color-id='#{confirmed.id}']" do
      assert_select "tbody tr", count: 1
      assert_select "td", text: "110 Prototype", count: 0
    end
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

  test "admin adds a color directly without review" do
    sign_in_as(@admin)
    assert_difference -> { @lure.variants.count } => 1, -> { ModerationItem.count } => 0 do
      post variants_path(@lure, locale: :en), params: { variant: { name: "Pro Blue", uv_glow: "0" } }
    end
    assert_redirected_to edit_lure_path(@lure)
    assert @lure.variants.order(:id).last.published?, "an admin's color is published immediately"
  end

  test "a member's new color is queued and hidden from the public lure page until approved" do
    sign_in_as(@member)
    assert_difference -> { @lure.variants.count } => 1, -> { ModerationItem.where(kind: :catalog).count } => 1 do
      post variants_path(@lure, locale: :en), params: { variant: { name: "Member Blue", uv_glow: "0" } }
    end
    variant = @lure.variants.order(:id).last
    assert_not variant.published?

    sign_out
    get lure_path(@lure, locale: :en)
    assert_response :success
    assert_no_match "Member Blue", response.body, "a pending color must not show publicly"
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

  test "admin confirms a color's builds directly, with the change recorded in the revision" do
    other = @lure.builds.create!(name: "110 F")
    sign_in_as(@admin)

    patch variant_path(@lure, @color, locale: :en),
          params: { variant: { name: @color.name, build_ids: [ "", @build.id.to_s ] } }

    assert_equal [ @build.id ], @color.reload.build_ids
    assert_equal [ [], [ @build.id ] ], Revision.last.changeset["build_ids"]
    assert_not_includes @color.build_ids, other.id
  end

  test "a member's build_ids suggestion applies on approval and rolls back on undo" do
    sign_in_as(@member)
    assert_difference -> { Revision.count } => 1, -> { ModerationItem.count } => 1 do
      patch variant_path(@lure, @color, locale: :en),
            params: { variant: { name: @color.name, build_ids: [ "", @build.id.to_s ] } }
    end
    assert_not @color.reload.availability_known?, "a suggestion must not touch the record"

    item = ModerationItem.last
    item.approve!(@admin)
    assert_equal [ @build.id ], @color.reload.build_ids

    item.undo!
    assert_not @color.reload.availability_known?, "undo restores the open-world unknown state"
  end

  test "a new color can be born with confirmed builds" do
    sign_in_as(@admin)
    post variants_path(@lure, locale: :en),
         params: { variant: { name: "Pro Blue", build_ids: [ "", @build.id.to_s ] } }

    assert_equal [ @build.id ], @lure.variants.order(:id).last.build_ids
  end

  test "moderation queue shows build names, not raw ids, for a build_ids suggestion" do
    sign_in_as(@member)
    patch variant_path(@lure, @color, locale: :en),
          params: { variant: { name: @color.name, build_ids: [ "", @build.id.to_s ] } }

    sign_in_as(@admin)
    get moderation_index_path(locale: :en)
    assert_response :success
    assert_match "110 SP", response.body
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
