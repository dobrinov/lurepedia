require "test_helper"

# Brands accept a logo upload and a website, and the logo survives the
# moderation queue the same way species photos do.
class BrandAttributesTest < ActionDispatch::IntegrationTest
  def setup
    @member = users(:two) # a plain member — edits go through review
    @admin = users(:one)
    @logo = fixture_file_upload("avatar.png", "image/png")
  end

  test "creating a brand stores its website and attaches its logo" do
    sign_in_as(@member)
    assert_difference -> { Brand.count }, 1 do
      post brands_path(locale: :en), params: { brand: { name: "Megabass", website: "https://megabass.co.jp", logo: @logo } }
    end

    brand = Brand.order(:id).last
    assert_equal "https://megabass.co.jp", brand.website
    assert brand.logo.attached?
  end

  test "an invalid website is rejected" do
    sign_in_as(@member)
    assert_no_difference -> { Brand.count } do
      post brands_path(locale: :en), params: { brand: { name: "Bad URL", website: "not-a-url" } }
    end
  end

  test "a member's suggested logo is attached when a moderator approves it" do
    brand = Brand.create!(name: "Lucky Craft")
    sign_in_as(@member)

    assert_difference -> { ModerationItem.where(kind: :edit).count }, 1 do
      patch brand_path(brand, locale: :en), params: { brand: { logo: @logo } }
    end
    assert_not brand.reload.logo.attached?, "should not attach before approval"

    item = ModerationItem.where(kind: :edit, subject: brand).last
    item.approve!(@admin)
    assert brand.reload.logo.attached?, "approving should attach the suggested logo"
  end
end
