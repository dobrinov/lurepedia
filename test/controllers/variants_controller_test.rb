require "test_helper"

class VariantsControllerTest < ActionDispatch::IntegrationTest
  def setup
    @admin = users(:one)
    @member = users(:two)
    @type = LureType.create!(key: "crankbait")
    @brand = Brand.create!(name: "Strike King")
    @lure = Lure.create!(brand: @brand, lure_type: @type, model: "KVD 1.5")
    @variant = @lure.variants.create!(name: "Sexy Shad")
    @variant.photo.attach(
      io: file_fixture("avatar.png").open, filename: "avatar.png", content_type: "image/png"
    )
  end

  CROP = { photo_crop_x: 10, photo_crop_y: 20, photo_crop_w: 300, photo_crop_h: 200 }.freeze

  test "admin crops a photo directly" do
    sign_in_as @admin

    patch variant_path(lure_id: @lure, id: @variant), params: { variant: CROP }
    assert_redirected_to edit_lure_path(@lure)
    assert_equal "300x200+10+20", @variant.reload.photo_crop_geometry
    assert @variant.revisions.applied.any? { |r| r.changeset&.key?("photo_crop_w") }
  end

  test "member crop lands as a pending suggestion, not on the record" do
    sign_in_as @member

    assert_difference [ "Revision.count", "ModerationItem.count" ], 1 do
      patch variant_path(lure_id: @lure, id: @variant), params: { variant: CROP }
    end
    assert_nil @variant.reload.photo_crop_geometry

    revision = @variant.revisions.order(:id).last
    assert_not revision.applied?
    assert_equal [ nil, 300 ], revision.changeset["photo_crop_w"]
  end

  test "admin applies a background color to all colors" do
    sibling = @lure.variants.create!(name: "Firetiger", photo_bg_color: "#111111")
    sign_in_as @admin

    patch variant_path(lure_id: @lure, id: @variant),
          params: { variant: { photo_bg_color: "#aabbcc" }, apply_bg_to_all: "1" }

    assert_equal "#aabbcc", @variant.reload.photo_bg_color
    assert_equal "#aabbcc", sibling.reload.photo_bg_color
    assert sibling.revisions.applied.any? { |r| r.changeset&.key?("photo_bg_color") }
  end

  test "member's apply-to-all flag is ignored" do
    sibling = @lure.variants.create!(name: "Firetiger", photo_bg_color: "#111111")
    sign_in_as @member

    patch variant_path(lure_id: @lure, id: @variant),
          params: { variant: { photo_bg_color: "#aabbcc" }, apply_bg_to_all: "1" }

    assert_equal "#111111", sibling.reload.photo_bg_color
  end

  test "clearing crop fields removes the crop" do
    @variant.update!(CROP)
    sign_in_as @admin

    patch variant_path(lure_id: @lure, id: @variant),
          params: { variant: { photo_crop_x: "", photo_crop_y: "", photo_crop_w: "", photo_crop_h: "" } }
    assert_nil @variant.reload.photo_crop_geometry
  end
end
