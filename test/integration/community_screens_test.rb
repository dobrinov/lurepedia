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
    @catch = create_catch(user: @member, variant: @variant, species: @bass, upvotes_count: 3, length_cm: 50)
  end

  # A catch may be logged without a build (the size is optional); the detail
  # page and the shared catch card must not assume one is present.
  test "a catch without a build renders on its page and in listings" do
    buildless = Catch.create!(user: @member, variant: @variant, species: @bass)
    assert_nil buildless.build

    get catch_path(buildless, locale: :en)
    assert_response :success

    get catches_path(locale: :en)
    assert_response :success
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
        user: { name: "New Angler", email_address: "new@example.com", password: "secret123", country: "DE", locale: "de" }
      }
    end
    assert User.find_by(email_address: "new@example.com").member?
  end

  test "settings require login then update" do
    get edit_settings_path(locale: :en)
    assert_redirected_to new_session_path(locale: :en)

    sign_in_as(@member)
    patch settings_path(locale: :en), params: { user: { weight_units: "metric", length_units: "imperial", locale: "de", country: "CA" } }
    @member.reload
    assert_equal "metric", @member.weight_units
    assert_equal "imperial", @member.length_units
    assert_equal "ca", @member.country.downcase
  end

  test "my catches redirects to the member's profile" do
    sign_in_as(@member)
    get my_catches_path(locale: :en)
    # Signed-in users get locale-free URLs.
    assert_redirected_to profile_path(@member)
  end

  test "member suggesting a lure edit files a reviewed suggestion without applying it" do
    sign_in_as(@member)
    assert_difference -> { Revision.count } => 1, -> { ModerationItem.where(kind: :edit).count } => 1 do
      patch lure_path(@lure, locale: :en), params: { lure: { model: "Vision 110 PROPOSED" } }
    end
    assert_equal "Vision 110", @lure.reload.model # not applied for non-admin
  end

  test "admin editing a lure applies directly without moderation" do
    sign_in_as(@admin)
    assert_no_difference -> { ModerationItem.where(kind: :edit).count } do
      patch lure_path(@lure, locale: :en), params: { lure: { model: "Vision 110 MkII" } }
    end
    assert_equal "Vision 110 MkII", @lure.reload.model
  end

  test "edit pages render with role-appropriate affordance" do
    sign_in_as(@member)
    get edit_species_path(@bass, locale: :en)
    assert_response :success
    assert_match I18n.t("contribute.suggest_edit"), response.body

    sign_in_as(@admin)
    get edit_brand_path(@brand, locale: :en)
    assert_response :success
    assert_match I18n.t("common.edit"), response.body
  end

  test "species detail shows an edit affordance" do
    get species_path(@bass, locale: :en)
    assert_match I18n.t("contribute.suggest_edit"), response.body
    assert_select "a[href=?]", new_session_path(locale: :en)
    sign_in_as(@member)
    get species_path(@bass, locale: :en)
    assert_match I18n.t("contribute.suggest_edit"), response.body
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
    # Signed-in users get locale-free URLs.
    assert_redirected_to localized_root_path

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
    # Signed-in users get locale-free URLs.
    assert_redirected_to localized_root_path

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

  test "upvote button reflects upvoted state" do
    type = LureType.create!(key: "spinnerbait")
    brand = Brand.create!(name: "Booyah")
    lure = Lure.create!(brand: brand, lure_type: type, model: "Pond Magic")
    variant = lure.variants.create!(name: "Shad")
    species = Species.create!(key: "smallmouth_bass")
    voter = User.create!(name: "Vic Voter", email_address: "vic@example.com", password: "secret123")
    catch = create_catch(user: voter, variant: variant, species: species)
    Upvote.create!(user: voter, catch: catch)

    sign_in_as(voter)
    get catch_path(catch, locale: :en)
    assert_response :success
    assert_select ".btn.is-upvoted"
  end

  test "footer uses translated labels and no copyright" do
    get "/en"
    assert_response :success
    assert_select "footer.site-footer" do
      assert_select "h4", text: I18n.t("footer.explore")
      assert_select "a", text: I18n.t("nav.species")
    end
    assert_no_match(/©/, response.body)
    assert_no_match(/&amp; more/, response.body)
  end
end
