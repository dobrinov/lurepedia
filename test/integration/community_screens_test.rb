require "test_helper"

class CommunityScreensTest < ActionDispatch::IntegrationTest
  def setup
    @type = LureType.create!(key: "jerkbait")
    @brand = Brand.create!(name: "Megabass")
    @lure = Lure.create!(brand: @brand, lure_type: @type, model: "Vision 110")
    @variant = @lure.variants.create!(name: "GG Ayu")
    @bass = Species.create!(key: "largemouth_bass", scientific_name: "Micropterus salmoides")
    @member = User.create!(name: "Mia Member", email_address: "mia@example.com", password: "secret123", role: :member, country: "US")
    @moderator = User.create!(name: "Mod Max", email_address: "max@example.com", password: "secret123", role: :moderator)
    @admin = User.create!(name: "Ada Admin", email_address: "ada@example.com", password: "secret123", role: :admin)
    @catch = Catch.create!(user: @member, variant: @variant, species: @bass, upvotes_count: 3, length_cm: 50)
  end

  test "search finds lures species brands" do
    get search_path(locale: :en, q: "Vision")
    assert_response :success
    assert_match "Vision 110", response.body
    get search_path(locale: :en, q: "Largemouth")
    assert_match "Largemouth Bass", response.body
  end

  test "search empty state" do
    get search_path(locale: :en, q: "zzzznotfound")
    assert_match I18n.t("search.no_results"), response.body
  end

  test "leaderboard ranks and toggles metric" do
    get leaderboard_path(locale: :en)
    assert_response :success
    assert_match "Mia Member", response.body
    get leaderboard_path(locale: :en, metric: "upvotes")
    assert_response :success
    get leaderboard_path(locale: :en, metric: "length")
    assert_response :success
  end

  test "registration creates a member and signs in" do
    assert_difference -> { User.count }, 1 do
      post registration_path(locale: :en), params: {
        user: { name: "New Angler", email_address: "new@example.com", password: "secret123", country: "DE", locale: "de", units: "metric" }
      }
    end
    assert User.find_by(email_address: "new@example.com").member?
  end

  test "settings require login then update" do
    get edit_settings_path(locale: :en)
    assert_redirected_to new_session_path(locale: :en)

    sign_in_as(@member)
    patch settings_path(locale: :en), params: { user: { units: "metric", locale: "de", country: "CA" } }
    assert_equal "metric", @member.reload.units
    assert_equal "ca", @member.country.downcase
  end

  test "my catches lists user catches" do
    sign_in_as(@member)
    get my_catches_path(locale: :en)
    assert_response :success
    assert_match I18n.t("dashboard.total_upvotes"), response.body
  end

  test "suggest edit creates revision and moderation item" do
    sign_in_as(@member)
    assert_difference -> { Revision.count } => 1, -> { ModerationItem.where(kind: :edit).count } => 1 do
      post revisions_path(locale: :en), params: { revision: { type: "lure", slug: @lure.slug, summary: "Fix depth" } }
    end
  end

  test "report creates report and moderation item" do
    sign_in_as(@member)
    assert_difference -> { Report.count } => 1, -> { ModerationItem.where(kind: :report).count } => 1 do
      post reports_path(locale: :en), params: { reportable_type: "Catch", reportable_id: @catch.id, report: { reason: "fake", note: "looks off" } }
    end
  end

  test "claim flow: create then verify" do
    sign_in_as(@member)
    post claims_path(locale: :en), params: { claim: { type: "brand", email: "owner@megabass.com" }, slug: @brand.slug }
    claim = @brand.reload.claim
    assert claim.present?
    post verify_claim_path(claim, locale: :en)
    assert claim.reload.status_verified?
    assert @brand.reload.claimed?
  end

  test "moderation queue requires moderator" do
    get moderation_index_path(locale: :en)
    assert_redirected_to new_session_path(locale: :en)

    sign_in_as(@member)
    get moderation_index_path(locale: :en)
    assert_redirected_to localized_root_path(locale: :en)

    sign_in_as(@moderator)
    get moderation_index_path(locale: :en)
    assert_response :success
  end

  test "moderator can approve a catch but not a claim" do
    catch_item = ModerationItem.create!(subject: @catch, kind: :catch, submitter: @member, mod_actionable: true)
    claim = Claim.create!(claimable: @brand, user: @member, email: "o@x.com")
    claim_item = ModerationItem.create!(subject: claim, kind: :claim, submitter: @member, mod_actionable: false)

    sign_in_as(@moderator)
    patch moderation_path(catch_item, locale: :en), params: { decision: "approve" }
    assert catch_item.reload.status_approved?

    patch moderation_path(claim_item, locale: :en), params: { decision: "approve" }
    assert_not claim_item.reload.status_approved?
  end

  test "admin console gated to admins" do
    sign_in_as(@moderator)
    get admin_root_path(locale: :en)
    assert_redirected_to localized_root_path(locale: :en)

    sign_in_as(@admin)
    get admin_root_path(locale: :en)
    assert_response :success
    get admin_people_path(locale: :en)
    assert_response :success
  end

  test "admin can change a user role" do
    sign_in_as(@admin)
    patch admin_user_path(@member, locale: :en), params: { user: { role: "moderator" } }
    assert @member.reload.moderator?
  end
end
