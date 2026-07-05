# Backfill the color<->build availability matrix (variant_builds) from an
# availability JSON. Use this when confirming availability for records that
# already exist (e.g. a per-brand scrape done after the fact); new imports
# should instead carry per-color "builds" lists in the catalog JSON consumed
# by import_catalog.rb.
#
#   bin/rails runner script/import/backfill_variant_builds.rb availability.json
#
# Format: [ { "brand": ..., "model": ..., "build": ..., "colors": [names] } ]
#
# Additive and idempotent: only creates missing VariantBuild rows for records
# matched by natural names (brand -> lure.model -> build.name / variant.name);
# never deletes, never touches photos, so it is safe to re-run and cheap enough
# for the prod machine. Unmatched names are reported, not guessed — under the
# open-world model a skipped color simply stays "availability unknown".
require "json"

path = ARGV[0] or abort "usage: bin/rails runner script/import/backfill_variant_builds.rb <availability.json>"
entries = JSON.parse(File.read(path))

# The same brand can be named differently across environments (dev "DUO",
# prod "DUO International") — try known aliases before giving up.
BRAND_ALIASES = { "DUO" => [ "DUO", "DUO International" ] }.freeze

stats = Hash.new(0)
misses = Hash.new { |h, k| h[k] = [] }

entries.group_by { |e| e["brand"] }.each do |brand_name, brand_entries|
  brand = BRAND_ALIASES.fetch(brand_name, [ brand_name ]).lazy.filter_map { |n| Brand.find_by(name: n) }.first
  next misses[:brand] << brand_name unless brand

  brand_entries.group_by { |e| e["model"] }.each do |model, lure_entries|
    lure = brand.lures.find_by(model: model)
    next misses[:lure] << "#{brand_name} #{model}" unless lure

    builds = lure.builds.index_by(&:name)
    variants = lure.variants.index_by(&:name)

    lure_entries.each do |entry|
      build = builds[entry["build"]]
      next misses[:build] << "#{brand_name} #{model} — #{entry["build"]}" unless build

      entry["colors"].each do |color|
        variant = variants[color]
        next misses[:color] << "#{brand_name} #{model} — #{color}" unless variant

        VariantBuild.find_or_create_by!(variant: variant, build: build) { stats[:created] += 1 }
        stats[:rows] += 1
      end
    end
  end
end

puts "confirmed #{stats[:rows]} color/build pairs (#{stats[:created]} new rows)"
misses.each do |kind, names|
  puts "unmatched #{kind} (#{names.uniq.size}):"
  names.uniq.first(20).each { |n| puts "  #{n}" }
end
