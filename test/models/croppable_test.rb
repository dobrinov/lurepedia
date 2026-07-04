require "test_helper"

class CroppableTest < ActiveSupport::TestCase
  def setup
    @type = LureType.create!(key: "crankbait")
    @brand = Brand.create!(name: "Strike King")
    @lure = Lure.create!(brand: @brand, lure_type: @type, model: "KVD 1.5")
    @variant = @lure.variants.create!(name: "Sexy Shad")
    @variant.photo.attach(photo_blob)
  end

  def photo_blob
    ActiveStorage::Blob.create_and_upload!(
      io: file_fixture("avatar.png").open, filename: "avatar.png", content_type: "image/png"
    )
  end

  test "no crop by default" do
    assert_not @variant.photo_crop?
    assert_nil @variant.photo_crop_geometry
  end

  test "crop renders as ImageMagick geometry" do
    @variant.update!(photo_crop_x: 10, photo_crop_y: 20, photo_crop_w: 300, photo_crop_h: 200)
    assert @variant.photo_crop?
    assert_equal "300x200+10+20", @variant.photo_crop_geometry
  end

  test "crop fields are all-or-none" do
    @variant.assign_attributes(photo_crop_x: 10, photo_crop_w: 300)
    assert_not @variant.valid?
  end

  test "crop must have positive size and non-negative origin" do
    @variant.assign_attributes(photo_crop_x: 0, photo_crop_y: 0, photo_crop_w: 0, photo_crop_h: 100)
    assert_not @variant.valid?

    @variant.assign_attributes(photo_crop_x: -5, photo_crop_y: 0, photo_crop_w: 100, photo_crop_h: 100)
    assert_not @variant.valid?
  end

  test "replacing the photo clears the crop" do
    @variant.update!(photo_crop_x: 10, photo_crop_y: 20, photo_crop_w: 300, photo_crop_h: 200)
    @variant.update!(photo: photo_blob)
    assert_nil @variant.reload.photo_crop_geometry
  end

  test "replacing photo and crop together keeps the new crop" do
    @variant.update!(photo_crop_x: 10, photo_crop_y: 20, photo_crop_w: 300, photo_crop_h: 200)
    @variant.update!(photo: photo_blob, photo_crop_x: 1, photo_crop_y: 2, photo_crop_w: 30, photo_crop_h: 20)
    assert_equal "30x20+1+2", @variant.reload.photo_crop_geometry
  end

  test "manual background color overrides the measured one" do
    @variant.photo.blob.update!(metadata: @variant.photo.blob.metadata.merge("background_color" => "#111111"))
    assert_equal "#111111", @variant.photo_background_color

    @variant.update!(photo_bg_color: "#ff8800")
    assert_equal "#ff8800", @variant.photo_background_color
  end

  test "background color must be a hex color" do
    @variant.photo_bg_color = "red"
    assert_not @variant.valid?

    @variant.photo_bg_color = "#ff8800"
    assert @variant.valid?
  end

  test "replacing the photo clears the background override" do
    @variant.update!(photo_bg_color: "#ff8800")
    @variant.update!(photo: photo_blob)
    assert_nil @variant.reload.photo_bg_color
  end

  test "species is croppable too" do
    species = Species.create!(key: "largemouth_bass")
    species.update!(photo_crop_x: 0, photo_crop_y: 0, photo_crop_w: 40, photo_crop_h: 25)
    assert_equal "40x25+0+0", species.photo_crop_geometry
  end
end
