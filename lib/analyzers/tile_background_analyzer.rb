# The stock image analysis (width/height) plus the photo's dominant border
# color, stored in blob metadata as "background_color" => "#rrggbb". Square
# tiles letterbox contain-fit photos; painting the tile with the photo's own
# edge color makes the bars blend into the image
# (ApplicationHelper#photo_frame_style).
#
# Runs in ActiveStorage::AnalyzeJob when a blob is attached. Existing blobs
# are backfilled with `bin/rails images:backfill_backgrounds`. Required and
# registered by config/initializers/active_storage_analyzers.rb; not
# autoloaded, so editing it needs a server restart.
class TileBackgroundAnalyzer < ActiveStorage::Analyzer::ImageAnalyzer::ImageMagick
  SAMPLE = 24 # px — the whole image is resampled to SAMPLE×SAMPLE first
  PIXEL = /^(\d+),(\d+):\s+\((\d+),(\d+),(\d+)(?:,(\d+))?\)/

  def metadata
    super.merge(background_color: background_color).compact
  end

  private

  def background_color
    download_blob_to_tempfile do |file|
      pixels = border_pixels(file.path)
      average_hex(pixels) if pixels.size >= edge_pixel_count / 2
    end
  rescue MiniMagick::Error
    nil
  end

  # RGB triplets of the opaque pixels on the resampled image's 1px border —
  # the pixels that end up adjacent to any letterbox bar.
  def border_pixels(path)
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
      next unless x.zero? || y.zero? || x == SAMPLE - 1 || y == SAMPLE - 1
      next if a && a < 128 # transparent edges: let the default tile show

      [ r, g, b ]
    end
  end

  def edge_pixel_count
    SAMPLE * 4 - 4
  end

  def average_hex(pixels)
    r, g, b = pixels.transpose.map { |channel| channel.sum / channel.size }
    format("#%02x%02x%02x", r, g, b)
  end
end
