namespace :images do
  desc "Re-analyze image blobs the tile background analyzer hasn't seen yet"
  task backfill_backgrounds: :environment do
    scope = ActiveStorage::Blob.where("content_type LIKE 'image/%'")
    scope.find_each do |blob|
      # The analyzer stores false for "analyzed, no usable color" (transparent
      # edges), so key presence — not value — marks a blob as done.
      next if blob.metadata.key?("background_color")

      blob.analyze
      puts "#{blob.filename}: #{blob.metadata["background_color"] || "no color (transparent edges?)"}"
    rescue StandardError => e
      warn "#{blob.filename}: #{e.class} #{e.message}"
    end
  end
end
