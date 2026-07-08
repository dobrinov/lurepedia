namespace :images do
  desc "Re-analyze image blobs the tile background analyzer hasn't seen yet"
  task backfill_backgrounds: :environment do
    scope = ActiveStorage::Blob.where("content_type LIKE 'image/%'")
    scope.find_each do |blob|
      # The analyzer stores false for "analyzed, no usable value" (transparent
      # edges, uniform image), so key presence — not value — marks a blob as
      # done for both the background color and the color signature.
      next if blob.metadata.key?("background_color") && blob.metadata.key?("color_signature")

      blob.analyze
      background = blob.metadata["background_color"] || "no color (transparent edges?)"
      signature = blob.metadata["color_signature"] ? "signature ok" : "no signature (uniform image?)"
      puts "#{blob.filename}: #{background}, #{signature}"
    rescue StandardError => e
      warn "#{blob.filename}: #{e.class} #{e.message}"
    end
  end

  desc "Recompute background_color for every image blob (corner-pixel method), preserving color_signature"
  task recalc_backgrounds: :environment do
    analyzer = TileBackgroundAnalyzer.allocate
    scope = ActiveStorage::Blob.where("content_type LIKE 'image/%'")
    total = scope.count
    done = changed = 0

    scope.find_each do |blob|
      # Recompute only the background color; leave color_signature (and the
      # similar-lure proposals it feeds) untouched, and touch no storage files.
      color = blob.open { |file| analyzer.send(:corner_pixels, file.path) }
                   .then { |px| px.size >= 2 ? analyzer.send(:median_hex, px) : false }
      before = blob.metadata["background_color"]
      blob.update!(metadata: blob.metadata.merge("background_color" => color))

      done += 1
      changed += 1 if before != color
      puts "#{blob.filename}: #{before.inspect} -> #{color.inspect}" if before != color
      puts "  …#{done}/#{total}" if (done % 200).zero?
    rescue StandardError => e
      warn "#{blob.filename}: #{e.class} #{e.message}"
    end

    puts "Recalculated #{done}/#{total} blobs; #{changed} background colors changed."
  end
end
