namespace :images do
  desc "Re-analyze image blobs that don't have a tile background color yet"
  task backfill_backgrounds: :environment do
    scope = ActiveStorage::Blob.where("content_type LIKE 'image/%'")
    scope.find_each do |blob|
      next if blob.metadata["background_color"].present?

      blob.analyze
      puts "#{blob.filename}: #{blob.metadata["background_color"] || "no color (transparent edges?)"}"
    rescue StandardError => e
      warn "#{blob.filename}: #{e.class} #{e.message}"
    end
  end
end
