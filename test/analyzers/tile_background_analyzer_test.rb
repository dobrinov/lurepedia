require "test_helper"

class TileBackgroundAnalyzerTest < ActiveSupport::TestCase
  # A blob whose image is `spec` (an ImageMagick canvas/gradient recipe).
  def blob_for(spec, type: "png")
    path = File.join(Dir.mktmpdir, "sample.#{type}")
    MiniMagick.convert do |c|
      c.size("120x80")
      c << spec
      c << path
    end
    ActiveStorage::Blob.create_and_upload!(
      io: File.open(path), filename: File.basename(path), content_type: "image/#{type}"
    )
  end

  test "solid image yields its color and keeps stock dimensions" do
    blob = blob_for("canvas:#336699")
    blob.analyze

    assert_equal "#336699", blob.metadata["background_color"]
    assert_equal 120, blob.metadata["width"]
    assert_equal 80, blob.metadata["height"]
  end

  test "border color wins over the center" do
    # Red canvas with a white center block: the letterbox-adjacent border is red.
    path = File.join(Dir.mktmpdir, "framed.png")
    MiniMagick.convert do |c|
      c.size("120x120")
      c << "canvas:red"
      c.fill("white")
      c.draw("rectangle 30,30 90,90")
      c << path
    end
    blob = ActiveStorage::Blob.create_and_upload!(io: File.open(path), filename: "framed.png", content_type: "image/png")
    blob.analyze

    assert_equal "#ff0000", blob.metadata["background_color"]
  end

  test "transparent edges store false so reruns can skip the blob" do
    blob = blob_for("canvas:transparent")
    blob.analyze

    assert blob.metadata.key?("background_color")
    assert_equal false, blob.metadata["background_color"]
  end
end
