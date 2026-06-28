require "test_helper"

# A member's new catalog entry is queued for review and stays hidden from the
# public catalog until a moderator approves it. Admins (and verified brand
# owners) publish directly.
class CatalogVisibilityTest < ActionDispatch::IntegrationTest
  def setup
    @member = users(:two)
    @admin = users(:one)
  end

  test "a member's new brand is hidden until approved" do
    sign_in_as(@member)
    assert_difference -> { ModerationItem.where(kind: :catalog).count }, 1 do
      post brands_path(locale: :en), params: { brand: { name: "Backroom Tackle" } }
    end
    brand = Brand.find_by!(name: "Backroom Tackle")
    assert_not brand.published?

    # The submitter can still see their own pending entry.
    get brand_path(brand, locale: :en)
    assert_response :success

    # The public cannot — not in the index, and the page 404s.
    sign_out
    get brands_path(locale: :en)
    assert_no_match "Backroom Tackle", response.body
    get brand_path(brand, locale: :en)
    assert_response :not_found

    # A moderator approves it; now it's public.
    ModerationItem.where(subject: brand, kind: :catalog).last.approve!(@admin)
    assert brand.reload.published?
    get brand_path(brand, locale: :en)
    assert_response :success
    get brands_path(locale: :en)
    assert_match "Backroom Tackle", response.body
  end

  test "an admin's new brand is published immediately with no queue item" do
    sign_in_as(@admin)
    assert_no_difference -> { ModerationItem.count } do
      post brands_path(locale: :en), params: { brand: { name: "Official Tackle" } }
    end
    brand = Brand.find_by!(name: "Official Tackle")
    assert brand.published?

    sign_out
    get brands_path(locale: :en)
    assert_match "Official Tackle", response.body
  end
end
