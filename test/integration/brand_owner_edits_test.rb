require "test_helper"

# A verified brand owner can edit the brand and its lures/variants/builds
# without moderation, the same way an admin does. Everyone else still files a
# reviewed suggestion.
class BrandOwnerEditsTest < ActionDispatch::IntegrationTest
  def setup
    @owner = users(:two) # a plain member
    @brand = Brand.create!(name: "Megabass")
    @type = LureType.create!(key: "jerkbait")
    @lure = Lure.create!(brand: @brand, lure_type: @type, model: "Vision 110", blurb: "Original blurb")
    @variant = @lure.variants.create!(name: "GG Bass")
    @build = @lure.builds.create!(name: "Standard")

    @brand.create_claim!(user: @owner, email: @owner.email_address).verify!
  end

  test "verified brand owner edits a lure directly without moderation" do
    sign_in_as(@owner)
    assert_no_difference -> { ModerationItem.where(kind: :edit).count } do
      patch lure_path(@lure, locale: :en), params: { lure: { blurb: "Owner blurb" } }
    end

    assert_equal "Owner blurb", @lure.reload.blurb
    assert_equal "Edited #{@lure.title}", @lure.revisions.newest_first.first.summary
  end

  test "brand owner edits a variant and a build directly" do
    sign_in_as(@owner)
    assert_no_difference -> { ModerationItem.where(kind: :edit).count } do
      patch variant_path(@lure, @variant, locale: :en), params: { variant: { best_for: "Clear water" } }
      patch build_path(@lure, @build, locale: :en), params: { build: { name: "Deep" } }
    end

    assert_equal "Clear water", @variant.reload.best_for
    assert_equal "Deep", @build.reload.name
  end

  test "owner of one brand cannot edit another brand's lure without review" do
    other = Lure.create!(brand: Brand.create!(name: "Lucky Craft"), lure_type: @type, model: "Pointer 100")

    sign_in_as(@owner)
    assert_difference -> { ModerationItem.where(kind: :edit).count }, 1 do
      patch lure_path(other, locale: :en), params: { lure: { blurb: "Sneaky blurb" } }
    end

    assert_not_equal "Sneaky blurb", other.reload.blurb
  end

  test "a member without a claim still goes through moderation" do
    member = User.create!(name: "No Claim", email_address: "noclaim@example.com", password: "secret123")
    sign_in_as(member)
    assert_difference -> { ModerationItem.where(kind: :edit).count }, 1 do
      patch lure_path(@lure, locale: :en), params: { lure: { blurb: "Suggested blurb" } }
    end

    assert_equal "Original blurb", @lure.reload.blurb
  end

  test "verified brand owner adds a lure to their brand without moderation" do
    sign_in_as(@owner)
    assert_no_difference -> { ModerationItem.where(kind: :catalog).count } do
      assert_difference -> { @brand.lures.count }, 1 do
        post lures_path(locale: :en), params: { lure: { brand_id: @brand.id, lure_type_id: @type.id, model: "Vision 95" } }
      end
    end

    lure = @brand.lures.order(:id).last
    assert_equal "Vision 95", lure.model
    assert_equal I18n.t("provenance.created"), lure.revisions.newest_first.first.summary
  end

  test "member adding a lure to a brand they do not own goes through moderation" do
    other = Brand.create!(name: "Lucky Craft")
    sign_in_as(@owner)
    assert_difference -> { ModerationItem.where(kind: :catalog).count }, 1 do
      post lures_path(locale: :en), params: { lure: { brand_id: other.id, lure_type_id: @type.id, model: "Pointer 78" } }
    end
  end

  test "add-lure form gives a brand owner the data to flag direct publishing" do
    sign_in_as(@owner)
    get new_lure_path(locale: :en)
    assert_response :success
    assert_select "[data-controller='catalog-review-note']" do
      assert_select "[data-catalog-review-note-owned-ids-value*=?]", @brand.id.to_s
      assert_select "[data-catalog-review-note-direct-value=?]", I18n.t("contribute.direct_note")
    end
    # No brand is selected yet, so the visible note still warns about review.
    assert_select "[data-catalog-review-note-target='note']", text: I18n.t("contribute.moderation_note")
  end

  test "add-lure form tells an admin their submission goes live immediately" do
    admin = User.create!(name: "Boss", email_address: "boss@example.com", password: "secret123", role: :admin)
    sign_in_as(admin)
    get new_lure_path(locale: :en)
    assert_response :success
    assert_select "[data-catalog-review-note-target='note']", text: I18n.t("contribute.direct_note")
  end

  test "lure page shows the owner an Edit affordance, not Suggest an edit" do
    sign_in_as(@owner)
    get lure_path(@lure, locale: :en)
    assert_response :success
    assert_select "a[href=?]", edit_lure_path(@lure), text: I18n.t("common.edit")
    assert_select "a", { text: I18n.t("contribute.suggest_edit"), count: 0 }
  end
end
