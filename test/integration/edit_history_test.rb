require "test_helper"

class EditHistoryTest < ActionDispatch::IntegrationTest
  def setup
    @admin = users(:one)
    @member = users(:two)
    brand = Brand.create!(name: "Z-Man")
    type = LureType.create!(key: "jerkbait")
    @lure = Lure.create!(brand: brand, lure_type: type, model: "Vision 110", water: :fresh, blurb: "Original blurb")
  end

  test "admin edit records a field-level changeset on the revision" do
    sign_in_as(@admin)
    patch lure_path(@lure, locale: :en), params: { lure: { blurb: "New blurb", water: "salt" } }

    rev = @lure.revisions.newest_first.first
    assert rev.edit?
    assert_equal [ "Original blurb", "New blurb" ], rev.changeset["blurb"]
    assert_equal [ "fresh", "salt" ], rev.changeset["water"]
  end

  test "member suggestion links the moderation item to the proposed-change revision" do
    sign_in_as(@member)
    patch lure_path(@lure, locale: :en), params: { lure: { blurb: "Suggested blurb" } }

    item = ModerationItem.where(subject: @lure, kind: :edit).last
    assert item.revision.present?
    assert_equal [ "Original blurb", "Suggested blurb" ], item.revision.changeset["blurb"]
  end

  test "history tab shows a generic 'edited' link, not the lure name, and links the contributor" do
    sign_in_as(@admin)
    patch lure_path(@lure, locale: :en), params: { lure: { blurb: "New blurb" } }
    rev = @lure.revisions.newest_first.first

    get lure_path(@lure, tab: "history", locale: :en)
    assert_response :success
    # Signed-in users get locale-free URLs.
    assert_select "a[href=?]", revision_path(rev), text: "edited"
    assert_select "a[href=?]", profile_path(@admin)
    assert_select "td", { text: /Vision 110/, count: 0 }, "history row should not repeat the lure name"
  end

  test "revision page renders a git-style diff with old and new values" do
    sign_in_as(@admin)
    patch lure_path(@lure, locale: :en), params: { lure: { blurb: "New blurb" } }
    rev = @lure.revisions.newest_first.first

    get revision_path(rev, locale: :en)
    assert_response :success
    assert_select ".diff-del .diff-text", text: "Original blurb"
    assert_select ".diff-ins .diff-text", text: "New blurb"
  end

  test "moderation queue renders the diff inline for an edit suggestion" do
    sign_in_as(@member)
    patch lure_path(@lure, locale: :en), params: { lure: { blurb: "Suggested blurb" } }
    sign_out

    sign_in_as(@admin)
    get moderation_index_path(locale: :en)
    assert_response :success
    assert_select ".diff-del .diff-text", text: "Original blurb"
    assert_select ".diff-ins .diff-text", text: "Suggested blurb"
  end
end
