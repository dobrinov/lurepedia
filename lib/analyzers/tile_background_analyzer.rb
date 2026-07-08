# The stock image analysis (width/height) plus the photo's corner color,
# stored in blob metadata as "background_color" => "#rrggbb". Square tiles
# letterbox contain-fit photos; painting the tile with the photo's own corner
# color makes the bars blend into the image
# (ApplicationHelper#photo_frame_style).
#
# Also stores the photo's color-distribution fingerprint as "color_signature"
# (see ColorSignature), which powers the similar-lure proposals shown while a
# contributor uploads a new color.
#
# Runs in ActiveStorage::AnalyzeJob when a blob is attached. Existing blobs
# are backfilled with `bin/rails images:backfill_backgrounds`. Required and
# registered by config/initializers/active_storage_analyzers.rb; not
# autoloaded, so editing it needs a server restart.
class TileBackgroundAnalyzer < ActiveStorage::Analyzer::ImageAnalyzer::ImageMagick
  SAMPLE = 24 # px — the whole image is resampled to SAMPLE×SAMPLE first
  PIXEL = /^(\d+),(\d+):\s+\((\d+),(\d+),(\d+)(?:,(\d+))?\)/

  # A colorless outcome (transparent edges, unreadable image) is stored as
  # `false` rather than omitted, so the backfill task can tell "analyzed, no
  # color" apart from "never analyzed" and skip it on reruns. Readers treat
  # false as absent (it is .blank?).
  def metadata
    super.merge(background_color: background_color || false, color_signature: color_signature || false)
  end

  private

  def color_signature
    download_blob_to_tempfile do |file|
      ColorSignature.from_file(file.path)&.to_s
    end
  rescue MiniMagick::Error
    nil
  end

  # The four corner pixels are the safest read of the studio background: a
  # centered lure never reaches a corner, whereas a body or diving lip that
  # touches a side would drag a whole-border average toward muddy grey. The
  # SAMPLE×SAMPLE forced resize already smooths each corner over a block of the
  # original, so one pixel per corner is a regional sample, not a lone dot.
  # Transparent corners (letterbox bars) don't vote, and the per-channel median
  # of the survivors shrugs off a single odd corner.
  def background_color
    download_blob_to_tempfile do |file|
      corners = corner_pixels(file.path)
      median_hex(corners) if corners.size >= 2
    end
  rescue MiniMagick::Error
    nil
  end

  # RGB triplets of the opaque pixels at the resampled image's four corners.
  def corner_pixels(path)
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
      next unless corner?(x, y)
      next if a && a < 128 # transparent corner: let the default tile show

      [ r, g, b ]
    end
  end

  def corner?(x, y)
    (x.zero? || x == SAMPLE - 1) && (y.zero? || y == SAMPLE - 1)
  end

  def median_hex(pixels)
    r, g, b = pixels.transpose.map { |channel| median(channel) }
    format("#%02x%02x%02x", r, g, b)
  end

  def median(values)
    sorted = values.sort
    mid = sorted.size / 2
    sorted.size.odd? ? sorted[mid] : (sorted[mid - 1] + sorted[mid]) / 2
  end
end
