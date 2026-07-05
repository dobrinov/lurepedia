require "test_helper"

class ColorSignatureTest < ActiveSupport::TestCase
  # A lure-like test image: a colored block on a flat studio background.
  def draw(fill, background: "white")
    path = File.join(Dir.mktmpdir, "#{fill}.png")
    MiniMagick.convert do |convert|
      convert.size("64x64")
      convert << "xc:#{background}"
      convert.fill(fill)
      convert.draw("rectangle 12,20 52,44")
      convert << path
    end
    path
  end

  test "the same image fingerprints identically" do
    path = draw("red")
    a = ColorSignature.from_file(path)
    b = ColorSignature.from_file(path)

    assert a
    assert_in_delta 1.0, a.similarity(b), 0.01
  end

  test "different-colored subjects score low" do
    red = ColorSignature.from_file(draw("red"))
    blue = ColorSignature.from_file(draw("blue"))

    assert red.similarity(blue) < 0.3
  end

  test "a near-solid image has no usable signature" do
    path = File.join(Dir.mktmpdir, "solid.png")
    MiniMagick.convert do |convert|
      convert.size("64x64")
      convert << "xc:gray"
      convert << path
    end

    assert_nil ColorSignature.from_file(path)
  end

  test "serializes and parses losslessly" do
    signature = ColorSignature.from_file(draw("green"))
    parsed = ColorSignature.parse(signature.to_s)

    assert_equal signature.bins, parsed.bins
  end

  test "parse rejects malformed input" do
    assert_nil ColorSignature.parse(nil)
    assert_nil ColorSignature.parse("zz")
    assert_nil ColorSignature.parse("ab" * 63)
  end
end
