# Compact color-distribution fingerprint of a lure photo, used to propose
# existing look-alikes while a contributor uploads a new color
# (SimilarLureSuggestions).
#
# The image is resampled to SAMPLE×SAMPLE with the same ImageMagick txt: dump
# technique as TileBackgroundAnalyzer. Transparent pixels and pixels close to
# the image's own border average are dropped — catalog shots are lures on flat
# studio backgrounds, and without this the background dominates every
# histogram. Survivors are counted into a 4×4×4 RGB histogram whose 64 bin
# shares are normalized to 0–255 and serialized as 128 hex characters (stored
# in blob metadata under "color_signature").
class ColorSignature
  SAMPLE = 32
  LEVELS = 4 # quantization steps per RGB channel → 64 bins
  BINS = LEVELS**3
  BUCKET = 256 / LEVELS
  BACKGROUND_DISTANCE = 60 # Euclidean RGB distance treated as "still background"
  MIN_FOREGROUND = (SAMPLE * SAMPLE) / 10 # fewer surviving pixels → no usable signature
  PIXEL = /^(\d+),(\d+):\s+\((\d+),(\d+),(\d+)(?:,(\d+))?\)/

  attr_reader :bins

  class << self
    # Signature of the image at `path`, or nil when the image is unreadable or
    # too uniform to fingerprint (e.g. a solid color swatch).
    def from_file(path)
      pixels = opaque_pixels(path)
      foreground = without_background(pixels)
      return if foreground.size < MIN_FOREGROUND

      counts = Array.new(BINS, 0)
      foreground.each { |_x, _y, r, g, b| counts[bin_index(r, g, b)] += 1 }
      new(counts.map { |c| (c * 255.0 / foreground.size).round })
    rescue MiniMagick::Error
      nil
    end

    # Rehydrates a serialized signature; nil for anything malformed, so stale
    # or foreign metadata can't raise.
    def parse(hex)
      return unless hex.is_a?(String) && hex.match?(/\A\h{#{BINS * 2}}\z/)

      new(hex.scan(/\h{2}/).map { |byte| byte.to_i(16) })
    end

    private

    def opaque_pixels(path)
      dump = MiniMagick.convert do |convert|
        convert << path
        convert.resize("#{SAMPLE}x#{SAMPLE}!")
        convert.colorspace("sRGB")
        convert.depth(8)
        convert << "txt:-"
      end

      dump.lines.filter_map do |line|
        next unless (m = line.match(PIXEL))

        x, y, r, g, b, a = m.captures.map { |v| v&.to_i }
        [ x, y, r, g, b ] unless a && a < 128
      end
    end

    # Drops pixels near the border average — the flat studio background. When
    # the border is empty (fully transparent edges) every pixel is foreground.
    def without_background(pixels)
      border = pixels.select { |x, y, *| x.zero? || y.zero? || x == SAMPLE - 1 || y == SAMPLE - 1 }
      return pixels if border.empty?

      bg = border.map { |*, r, g, b| [ r, g, b ] }.transpose.map { |channel| channel.sum / channel.size }
      pixels.reject do |_x, _y, r, g, b|
        Math.sqrt((r - bg[0])**2 + (g - bg[1])**2 + (b - bg[2])**2) < BACKGROUND_DISTANCE
      end
    end

    def bin_index(r, g, b)
      (r / BUCKET) * LEVELS * LEVELS + (g / BUCKET) * LEVELS + (b / BUCKET)
    end
  end

  def initialize(bins)
    @bins = bins
  end

  def to_s
    bins.map { |b| format("%02x", b.clamp(0, 255)) }.join
  end

  # Histogram intersection: 1.0 for identical distributions, 0.0 for disjoint.
  def similarity(other)
    total = [ bins.sum, other.bins.sum ].max
    return 0.0 if total.zero?

    bins.zip(other.bins).sum { |a, b| [ a, b ].min } / total.to_f
  end
end
