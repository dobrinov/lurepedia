# Import a scraped brand catalog (JSON) into the current environment's DB.
# Idempotent: keyed on natural names (brand / lure model / build name / color
# name), so it is safe to re-run after a partial failure. Photos are attached
# only when missing.
#
#   bin/rails runner script/import/import_catalog.rb path/to/brand.json
#
# See script/import/README.md for the JSON format. The per-color "builds" list
# feeds the open-world variant_builds availability matrix: colors without it
# simply stay "availability unknown" (shown under every build) — never invent
# it when the source site doesn't publish per-size color charts.
require "json"
require "open-uri"

path = ARGV[0] or abort "usage: bin/rails runner script/import/import_catalog.rb <brand.json>"
data = JSON.parse(File.read(path))
base_dir = File.dirname(File.expand_path(path))

meta = data.fetch("brand")
brand = Brand.find_or_create_by!(name: meta.fetch("name")) do |b|
  b.country = meta["country"]
  b.website = meta["website"]
  b.founded_year = meta["founded_year"]
  b.blurb = meta["blurb"]
end
puts "== #{brand.name}"

stats = Hash.new(0)
data.fetch("lures").each do |spec|
  lure_type = LureType.find_by!(key: spec.fetch("lure_type"))
  lure = Lure.find_or_create_by!(brand: brand, model: spec.fetch("model")) do |l|
    l.lure_type = lure_type
    l.blurb = spec["blurb"]
    l.action_video_url = spec["video"]
    stats[:lures] += 1
  end

  builds = spec.fetch("builds").each_with_index.map { |bs, i|
    lure.builds.find_or_create_by!(name: bs.fetch("name")) do |b|
      b.length_mm = bs["length_mm"]
      b.weight_g = bs["weight_g"]
      b.depth_min_cm = bs["depth_min_cm"]
      b.depth_max_cm = bs["depth_max_cm"]
      b.action = bs["action"] || :none
      b.water = bs["water"] || :fresh
      b.position = bs["position"] || i
      stats[:builds] += 1
    end
  }.index_by(&:name)

  first_variant = nil
  spec.fetch("colors").each do |cs|
    variant = lure.variants.find_or_create_by!(name: cs.fetch("name")) do |v|
      v.uv_glow = cs["uv_glow"] || cs["uv"] || false
      stats[:variants] += 1
    end
    first_variant ||= variant

    # Availability: confirm this color to the builds the source site lists it
    # for. Absent list = open-world unknown; a name that matches no build is
    # reported, not guessed.
    Array(cs["builds"]).each do |build_name|
      build = builds[build_name]
      next (stats[:availability_misses] += 1) && puts("  ! no build #{build_name.inspect} for #{lure.model} / #{variant.name}") unless build

      VariantBuild.find_or_create_by!(variant: variant, build: build) { stats[:availability] += 1 }
    end

    next if variant.photo.attached?

    io, filename =
      if cs["file"]
        local = File.expand_path(cs["file"], base_dir)
        File.exist?(local) && File.size(local).positive? ? [ File.open(local), File.basename(local) ] : nil
      elsif cs["image"]
        begin
          [ URI.open(cs["image"], "User-Agent" => "Mozilla/5.0 (lurepedia catalog import)"),
            File.basename(URI(cs["image"]).path) ]
        rescue OpenURI::HTTPError, SocketError, Errno::ECONNRESET, Net::ReadTimeout => e
          puts "  ! photo failed: #{lure.model} / #{cs["name"]}: #{e.message}"
          nil
        end
      end
    next stats[:missing_photos] += 1 unless io

    # The in-Puma Solid Queue workers contend with the analyze-job enqueue on
    # the queue SQLite DB; a locked DB must not kill the import mid-run. The
    # analyze sweep after the run picks up any blob left unanalyzed here.
    begin
      variant.photo.attach(io: io, filename: "#{lure.slug}-#{variant.to_color_param}#{File.extname(filename)}")
      stats[:photos] += 1
    rescue SolidQueue::Job::EnqueueError, ActiveRecord::StatementTimeout => e
      puts "  ! attach enqueue failed (continuing): #{lure.model} / #{cs["name"]}: #{e.class}"
      stats[:photos] += 1 if variant.photo.attached?
    end
    sleep 0.15 if cs["image"]
  end

  lure.update!(default_variant: first_variant) if lure.default_variant_id.nil? && first_variant
  puts "  #{lure.model}: #{lure.builds.count} builds, #{lure.variants.count} colors"
end

puts "created — lures: #{stats[:lures]}, builds: #{stats[:builds]}, variants: #{stats[:variants]}, " \
     "availability pairs: #{stats[:availability]} (#{stats[:availability_misses]} misses), " \
     "photos: #{stats[:photos]} (#{stats[:missing_photos]} missing)"
