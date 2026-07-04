namespace :storage do
  desc "Copy blobs from the local Disk service to Tigris and repoint their service_name"
  task migrate_local_to_tigris: :environment do
    local  = ActiveStorage::Blob.services.fetch(:local)
    tigris = ActiveStorage::Blob.services.fetch(:tigris)

    scope = ActiveStorage::Blob.where(service_name: "local")
    total = scope.count
    migrated = 0
    missing = []

    scope.find_each do |blob|
      unless local.exist?(blob.key)
        missing << blob
        next
      end

      local.open(blob.key, checksum: blob.checksum) do |file|
        tigris.upload(blob.key, file,
          checksum: blob.checksum,
          filename: blob.filename,
          content_type: blob.content_type,
          disposition: :inline)
      end
      blob.update_columns(service_name: "tigris")
      migrated += 1
      puts "#{migrated}/#{total} #{blob.key} (#{blob.filename})"
    end

    puts "Done: #{migrated} migrated, #{missing.size} skipped (no file on disk)."
    missing.each { |blob| puts "  MISSING blob #{blob.id} #{blob.key} (#{blob.filename})" }
    puts "Remaining on local service: #{ActiveStorage::Blob.where(service_name: 'local').count}"
  end
end
