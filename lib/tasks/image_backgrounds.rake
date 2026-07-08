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
    # Over tens of thousands of blobs the per-download S3 INFO lines drown out
    # our own output (and bloat the log). Silence them; keep our puts.
    ActiveStorage.logger = Logger.new(IO::NULL)

    analyzer = TileBackgroundAnalyzer.allocate
    scope = ActiveStorage::Blob.where("content_type LIKE 'image/%'")
    total = scope.count
    done = changed = skipped = failed = 0

    scope.find_each(batch_size: 200) do |blob|
      # Resumable: a blob recomputed by a corner-method pass carries this
      # marker, so a relaunch after an interruption skips finished work
      # instead of redoing the whole catalog. New uploads are analyzed live
      # (no marker); this key is only a batch-backfill bookmark.
      if blob.metadata["bg_method"] == "corner"
        skipped += 1
        next
      end

      # Recompute only the background color; leave color_signature (and the
      # similar-lure proposals it feeds) untouched, and touch no storage files.
      color = blob.open { |file| analyzer.send(:corner_pixels, file.path) }
                   .then { |px| px.size >= 2 ? analyzer.send(:median_hex, px) : false }
      before = blob.metadata["background_color"]
      blob.update!(metadata: blob.metadata.merge("background_color" => color, "bg_method" => "corner"))

      done += 1
      changed += 1 if before != color
      puts "#{done + skipped}/#{total} #{blob.filename}: #{before.inspect} -> #{color.inspect}" if before != color
      $stdout.flush if ((done + skipped) % 200).zero?
    rescue StandardError => e
      failed += 1
      warn "#{blob.filename} (##{blob.id}): #{e.class} #{e.message}"
    end

    puts "Done. Recalculated #{done}, skipped #{skipped}, failed #{failed} of #{total}; #{changed} colors changed."
  end
end
