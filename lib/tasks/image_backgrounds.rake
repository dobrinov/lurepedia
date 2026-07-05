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
end
