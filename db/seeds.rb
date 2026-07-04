# Lurepedia seed data — realistic catalog + community content.
# Idempotent-ish: uses find_or_create_by on natural keys. Safe to re-run.
#
# This is DEMO data for local development and tests only. It creates fake
# accounts that all share the password "1" (including an admin), so it must
# never touch a real database. `db:prepare` runs seeds on first create, so
# guard here rather than relying on how the task is invoked.
unless Rails.env.local?
  warn "Skipping db/seeds.rb: demo seed data only runs in development and test."
  return
end

LURE_IMG = Rails.root.join("db/seeds/lure_images")
CATCH_IMG = Rails.root.join("db/seeds/catch_images")

def attach_once(attachable, association, path, filename, content_type)
  return unless File.exist?(path)
  return if attachable.public_send(association).attached?

  attachable.public_send(association).attach(io: File.open(path), filename: filename, content_type: content_type)
end

puts "Seeding Lurepedia…"

# ---------------------------------------------------------------- Users
def make_user(email, name, role, country, locale)
  User.find_or_create_by!(email_address: email) do |u|
    u.name = name
    u.role = role
    u.country = country
    u.locale = locale
    u.password = "1"
  end
end

admin = make_user("admin@example.com", "Casey Rivera", :admin, "US", "en")
moderator = make_user("moderator@example.com", "Marcus Lee", :moderator, "SE", "en")
members = [
  make_user("user1@example.com", "Dana Powell", :member, "GB", "en"),
  make_user("user2@example.com", "Aisha Khan", :member, "NL", "nl"),
  make_user("user3@example.com", "Jon Park", :member, "JP", "ja"),
  make_user("user4@example.com", "Tom Becker", :member, "DE", "de"),
  make_user("user5@example.com", "Ivan Petrov", :member, "BG", "bg")
]
all_contributors = [ admin, moderator, *members ]
puts "  users: #{User.count}"

# ---------------------------------------------------------------- Lure types
type_keys = %w[crankbait jerkbait soft_plastic spinnerbait bladed_jig topwater swimbait jig spoon lipless_crankbait]
types = type_keys.index_with { |k| LureType.find_or_create_by!(key: k) }
puts "  lure types: #{LureType.count}"

# ---------------------------------------------------------------- Brands
brand_data = [
  { name: "Megabass", country: "JP", founded_year: 1986, blurb: "High-end Japanese tackle with cult-favorite finishes." },
  { name: "Rapala", country: "FI", founded_year: 1936, blurb: "Finnish balsa pioneers; the original wounded-minnow wobble." },
  { name: "Strike King", country: "US", founded_year: 1966, blurb: "Tournament-proven baits at an everyday price." },
  { name: "Z-Man", country: "US", founded_year: 1985, blurb: "ElaZtech soft plastics and the original ChatterBait." },
  { name: "Booyah", country: "US", founded_year: 2003, blurb: "Spinnerbaits and buzzbaits built for big bites." },
  { name: "Berkley", country: "US", founded_year: 1937, blurb: "Science-driven soft plastics and PowerBait scents." },
  { name: "Shimano", country: "JP", founded_year: 1921, blurb: "Saltwater tackle and offshore metal jigs built for the deep." }
]
brands = {}
brand_data.each do |attrs|
  brands[attrs[:name]] = Brand.find_or_create_by!(name: attrs[:name]) do |brand|
    brand.assign_attributes(attrs.except(:blurb))
    brand.local_descriptions = { "en" => attrs[:blurb] }
  end
end
puts "  brands: #{Brand.count}"

# ---------------------------------------------------------------- Species
species_data = [
  { key: "largemouth_bass", sci: "Micropterus salmoides", water: :fresh },
  { key: "smallmouth_bass", sci: "Micropterus dolomieu", water: :fresh },
  { key: "northern_pike", sci: "Esox lucius", water: :fresh },
  { key: "walleye", sci: "Sander vitreus", water: :fresh },
  { key: "yellow_perch", sci: "Perca flavescens", water: :fresh },
  { key: "muskellunge", sci: "Esox masquinongy", water: :fresh },
  { key: "bluegill", sci: "Lepomis macrochirus", water: :fresh },
  { key: "rainbow_trout", sci: "Oncorhynchus mykiss", water: :fresh },     # unproven
  { key: "mahi_mahi", sci: "Coryphaena hippurus", water: :salt },
  { key: "striped_bass", sci: "Morone saxatilis", water: :salt },
  { key: "chinook_salmon", sci: "Oncorhynchus tshawytscha", water: :fresh },
  { key: "red_lionfish", sci: "Pterois volitans", water: :salt, venomous: true },     # unproven
  { key: "northern_puffer", sci: "Sphoeroides maculatus", water: :salt, poisonous: true } # unproven
]
species = {}
species_data.each do |attrs|
  species[attrs[:key]] = Species.find_or_create_by!(key: attrs[:key]) do |sp|
    sp.scientific_name = attrs[:sci]
    sp.water = attrs[:water]
    sp.venomous = attrs.fetch(:venomous, false)
    sp.poisonous = attrs.fetch(:poisonous, false)
  end
end
puts "  species: #{Species.count}"

# ---------------------------------------------------------------- Lures + variants
lure_specs = [
  { brand: "Megabass", model: "Vision 110", type: "jerkbait", depth: [ 120, 180 ], action: :suspending, img: "ghost-jerkbait.jpg",
    blurb: "A 110mm suspending jerkbait with a darting, erratic action that triggers reaction strikes.",
    video: "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
    variants: [ [ "GG Megabass Kanata Ayu", 110, 17.5 ], [ "Sexy French Pearl", 110, 17.5 ], [ "Pro Blue", 110, 17.5 ] ] },
  { brand: "Strike King", model: "KVD 1.5 Squarebill", type: "crankbait", depth: [ 90, 150 ], action: :floating, img: "firetiger-crank.jpg",
    blurb: "A squarebill crankbait that deflects off cover and draws explosive bites.",
    video: "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
    variants: [ [ "Chartreuse Sexy Shad", 60, 12.5 ], [ "Summer Craw", 60, 12.5 ] ] },
  { brand: "Z-Man", model: "Original ChatterBait", type: "bladed_jig", depth: [ 30, 240 ], action: :sinking, img: "bladed-chatter-jig.jpg",
    blurb: "The bladed swim jig that started it all — vibration that calls fish from afar.",
    variants: [ [ "Green Pumpkin", nil, 10.5 ], [ "White", nil, 10.5 ] ] },
  { brand: "Berkley", model: "PowerBait Power Worm", type: "soft_plastic", depth: [ 60, 360 ], action: :sinking, img: "paddle-tail-perch.jpg",
    blurb: "A scented ribbon-tail worm that bass can't leave alone.",
    variants: [ [ "Black Blue Fleck", 178, nil ], [ "Watermelon", 178, nil ] ] },
  { brand: "Booyah", model: "Pond Magic", type: "spinnerbait", depth: [ 30, 120 ], action: :none, img: "chartreuse-spinnerbait.jpg",
    blurb: "A compact spinnerbait sized for pressured ponds and panfish-eating bass.",
    variants: [ [ "Chartreuse Shad", nil, 5.0 ] ] },
  { brand: "Rapala", model: "Shadow Rap Deep", type: "jerkbait", depth: [ 150, 240 ], action: :suspending, img: "deep-diving-shad.jpg",
    blurb: "A deep-running jerkbait with a slow, fluttering kill.",
    variants: [ [ "Silver", 110, 15.0 ] ] }, # unproven (no catches)
  { brand: "Megabass", model: "Magdraft Swimbait", type: "swimbait", depth: [ 60, 240 ], action: :sinking, img: "jointed-trout-swimbait.jpg",
    blurb: "A line-through soft swimbait with a lifelike roll.",
    variants: [ [ "Rainbow Trout", 200, 56.0 ], [ "Gizzard Shad", 200, 56.0 ] ] },
  { brand: "Strike King", model: "Rage Swimmer", type: "swimbait", depth: [ 30, 180 ], action: :sinking, img: "pearl-shad-swimbait.jpg",
    blurb: "A paddle-tail swimbait with a hard thumping kick.",
    variants: [ [ "Pearl Flash", 95, 9.0 ] ] },
  { brand: "Z-Man", model: "DieZel MinnowZ", type: "swimbait", depth: [ 30, 150 ], action: :sinking, img: "rigged-paddle-swimbait.jpg",
    blurb: "Durable ElaZtech paddle-tail that survives toothy fish.",
    variants: [ [ "Redbone", 100, 8.0 ] ] },
  { brand: "Rapala", model: "Husky Jerk", type: "jerkbait", depth: [ 120, 240 ], action: :suspending, img: "suspending-minnow.jpg",
    blurb: "A suspending minnow that hangs in the strike zone.",
    variants: [ [ "Glass Ghost", 100, 10.0 ] ] },
  { brand: "Booyah", model: "Prop Knocker", type: "topwater", depth: [ 0, 15 ], action: :floating, img: "topwater-prop-bait.jpg",
    blurb: "A prop topwater that spits and sputters across the surface.",
    variants: [ [ "Bone", 95, 11.0 ] ] },
  { brand: "Strike King", model: "Flat Side Pro", type: "crankbait", depth: [ 90, 180 ], action: :floating, img: "flat-side-crank.jpg",
    blurb: "A flat-sided crank with a tight wiggle for cold water.",
    variants: [ [ "Chartreuse Black Back", 55, 9.5 ] ] },
  { brand: "Shimano", model: "Coltsniper Deep Sea Jig", type: "jig", depth: [ 3000, 8000 ], action: :sinking, water: :salt, img: "metal-jig-deep-sea.jpg",
    blurb: "A 160g knife-edge metal jig that plummets to the strike zone and flutters on the fall for offshore predators.",
    variants: [ [ "Blue Sardine", 170, 160.0 ] ] }
]

lures = {}
lure_specs.each do |spec|
  lure = Lure.find_or_create_by!(brand: brands.fetch(spec[:brand]), model: spec[:model]) do |l|
    l.lure_type = types.fetch(spec[:type])
    l.local_descriptions = { "en" => spec[:blurb] }
    l.action_video_url = spec[:video]
  end

  # One physical build per lure, derived from the spec; colors (variants) carry
  # the photo and catch the fish, and each is offered in that build. Buoyancy and
  # water suitability live on the build, so versions can differ (fresh vs. salt).
  rep_size = spec[:variants].filter_map { |(_n, size, _w)| size }.first
  rep_weight = spec[:variants].filter_map { |(_n, _s, weight)| weight }.first
  build = lure.builds.find_or_create_by!(name: "Standard") do |b|
    b.length_mm = rep_size
    b.weight_g = rep_weight
    b.depth_min_cm = spec[:depth][0]
    b.depth_max_cm = spec[:depth][1]
    b.action = spec[:action]
    b.water = spec[:water] || :fresh
  end

  colors = spec[:variants].map do |(vname, _size, _weight)|
    v = lure.variants.find_or_create_by!(name: vname)
    attach_once(v, :photo, LURE_IMG.join(spec[:img]), spec[:img], "image/jpeg")
    v
  end

  lure.update!(default_variant: colors.first) unless lure.default_variant_id
  lures[spec[:model]] = lure
end

# Showcase the two-axis model on Vision 110: extra builds and per-color metadata.
vision = lures["Vision 110"]
if vision
  extra_builds = {
    "110 +1 SP" => [ 110, 18.4, 150, 220, :suspending, :fresh ],
    "110 Jr SP"  => [ 88, 11.3, 90, 130, :suspending, :fresh ],
    "110 F"      => [ 110, 15.6, 30, 90, :floating, :fresh ],
    "110 SW"     => [ 110, 19.2, 60, 150, :suspending, :salt ]
  }
  extra_builds.each_with_index do |(name, (len, wt, dmin, dmax, act, wat)), i|
    vision.builds.find_or_create_by!(name: name) do |b|
      b.length_mm = len; b.weight_g = wt; b.depth_min_cm = dmin; b.depth_max_cm = dmax
      b.action = act; b.water = wat; b.position = i + 1
    end
  end
  color_meta = {
    "GG Megabass Kanata Ayu" => [ "Largemouth Bass · Clear water", true ],
    "Sexy French Pearl"      => [ "Smallmouth Bass · Stained water", false ],
    "Pro Blue"               => [ "Smallmouth Bass · Cold, clear", true ]
  }
  vision.variants.each do |v|
    best_for, uv = color_meta[v.name]
    next unless best_for

    v.update!(best_for: best_for, uv_glow: uv)
  end

  # Availability is open-world: colors with no confirmed builds show under every
  # build. Confirm one color to the Standard build only, so dev exercises both
  # the filtered table/caption and the unknown fallback.
  if (kanata = vision.variants.find_by(name: "GG Megabass Kanata Ayu")) &&
     (standard = vision.builds.find_by(name: "Standard"))
    VariantBuild.find_or_create_by!(variant: kanata, build: standard)
  end
end
puts "  lures: #{Lure.count}, variants: #{Variant.count}, builds: #{Build.count}"

# ---------------------------------------------------------------- Shops + buy links
# No promoted shops are seeded — the "Promoted" placement is left empty.
shop_data = [
  { name: "Bass Pro Shops", url: "basspro.com", promoted: false, ships_to: "US, CA, MX", blurb: "Outdoor retail giant." },
  { name: "FishUSA", url: "fishusa.com", promoted: false, ships_to: "US, CA", blurb: "Great Lakes and freshwater focus." },
  { name: "Karls Bait and Tackle", url: "karlsbait.com", promoted: false, ships_worldwide: true, blurb: "Community-driven tackle shop." },
  { name: "The Tackle Box", url: "thetacklebox.com", promoted: false, ships_to: "US", blurb: "Independent local shop, online." }
]
shops = {}
shop_data.each do |attrs|
  shops[attrs[:name]] = Shop.find_or_create_by!(name: attrs[:name]) { |shop| shop.assign_attributes(attrs) }
end

lures.values.each do |lure|
  [ shops["Bass Pro Shops"], shops["FishUSA"], shops["Karls Bait and Tackle"] ].each do |shop|
    BuyLink.find_or_create_by!(lure: lure, shop: shop) { |bl| bl.url = "#{shop.url}/#{lure.slug}" }
  end
end
puts "  shops: #{Shop.count}, buy links: #{BuyLink.count}"

# ---------------------------------------------------------------- Catches
# Single-fish photos per species (no collages). Each catch attaches the first
# `photos` images from its species' list, cycling if it needs more.
SPECIES_PHOTOS = {
  "largemouth_bass" => %w[bass_1.png bass_2.png],
  "smallmouth_bass" => %w[bass_2.png bass_1.png],
  "northern_pike" => %w[salmon_1.png],
  "walleye" => %w[salmon_2.png],
  "muskellunge" => %w[salmon_1.png salmon_2.png striper_1.png],
  "bluegill" => %w[bluegill_1.png bluegill_2.png],
  "yellow_perch" => %w[perch_1.png perch_2.png],
  "rainbow_trout" => %w[trout_1.png trout_2.png],
  "striped_bass" => %w[striper_1.png striper_2.png striper_3.png],
  "chinook_salmon" => %w[salmon_1.png salmon_2.png]
}.freeze

catch_specs = [
  { lure: "Vision 110", variant: "GG Megabass Kanata Ayu", species: "largemouth_bass", user: members[0], season: :spring, clarity: :clear, water_body: :lake, wind: :light, tod: :dawn, plat: :boat, ret: :jerk, loc: "Lake Fork, TX", len: 54.6, wt: 2359, up: 42, photos: 1 },
  { lure: "Vision 110", variant: "Pro Blue", species: "smallmouth_bass", user: members[2], season: :summer, clarity: :clear, water_body: :river, wind: :calm, tod: :morning, plat: :boat, ret: :twitch, loc: "Columbia River", len: 48.0, wt: 1800, up: 31, photos: 2 },
  { lure: "KVD 1.5 Squarebill", variant: "Chartreuse Sexy Shad", species: "largemouth_bass", user: members[1], season: :fall, clarity: :stained, water_body: :reservoir, wind: :moderate, tod: :afternoon, plat: :boat, ret: :steady, loc: "Lake Guntersville", len: 50.8, wt: 2100, up: 28, photos: 1 },
  { lure: "Original ChatterBait", variant: "Green Pumpkin", species: "largemouth_bass", user: admin, season: :spring, clarity: :stained, water_body: :pond, wind: :light, tod: :dusk, plat: :shore, ret: :burn, loc: "Private pond, GA", len: 47.0, wt: 1700, up: 63, photos: 1 },
  { lure: "Original ChatterBait", variant: "White", species: "northern_pike", user: members[3], season: :summer, clarity: :clear, water_body: :lake, wind: :moderate, tod: :midday, plat: :boat, ret: :steady, loc: "Lake of the Woods", len: 86.4, wt: 4500, up: 88, photos: 1 },
  { lure: "PowerBait Power Worm", variant: "Black Blue Fleck", species: "largemouth_bass", user: members[4], season: :summer, clarity: :muddy, water_body: :pond, wind: :calm, tod: :night, plat: :shore, ret: :dead_stick, loc: "Sofia reservoir", len: 44.0, wt: 1500, up: 19, photos: 1 },
  { lure: "Pond Magic", variant: "Chartreuse Shad", species: "bluegill", user: members[0], season: :summer, clarity: :clear, water_body: :pond, wind: :calm, tod: :morning, plat: :shore, ret: :stop_and_go, loc: "Neighborhood pond", len: 22.0, wt: 280, up: 12, photos: 2 },
  { lure: "Husky Jerk", variant: "Glass Ghost", species: "rainbow_trout", user: members[2], season: :spring, clarity: :clear, water_body: :stream, wind: :calm, tod: :morning, plat: :shore, ret: :twitch, loc: "Gunnison River, CO", len: 46.0, wt: 1200, up: 71, photos: 2 },
  { lure: "Husky Jerk", variant: "Glass Ghost", species: "walleye", user: moderator, season: :fall, clarity: :stained, water_body: :river, wind: :light, tod: :dusk, plat: :boat, ret: :jerk, loc: "Detroit River", len: 58.0, wt: 2600, up: 34, photos: 1 },
  { lure: "Prop Knocker", variant: "Bone", species: "smallmouth_bass", user: members[1], season: :summer, clarity: :clear, water_body: :lake, wind: :calm, tod: :dawn, plat: :boat, ret: :stop_and_go, loc: "Lake St. Clair", len: 45.0, wt: 1600, up: 41, photos: 2 },
  { lure: "Rage Swimmer", variant: "Pearl Flash", species: "striped_bass", user: members[3], season: :fall, clarity: :clear, water_body: :river, wind: :moderate, tod: :morning, plat: :kayak, ret: :slow_roll, loc: "Hudson River", len: 70.0, wt: 5000, up: 52, photos: 2 },
  { lure: "Magdraft Swimbait", variant: "Gizzard Shad", species: "chinook_salmon", user: members[2], season: :fall, clarity: :clear, water_body: :lake, wind: :light, tod: :dawn, plat: :boat, ret: :slow_roll, loc: "Lake Michigan", len: 92.0, wt: 8200, up: 84, photos: 2 },
  { lure: "DieZel MinnowZ", variant: "Redbone", species: "yellow_perch", user: members[4], season: :winter, clarity: :clear, water_body: :lake, wind: :calm, tod: :midday, plat: :boat, ret: :steady, loc: "Lake Erie", len: 30.0, wt: 450, up: 15, photos: 2 },
  { lure: "Flat Side Pro", variant: "Chartreuse Black Back", species: "smallmouth_bass", user: admin, season: :spring, clarity: :clear, water_body: :stream, wind: :light, tod: :afternoon, plat: :shore, ret: :twitch, loc: "Ozark creek", len: 40.0, wt: 1100, up: 23, photos: 1 },
  { lure: "Vision 110", variant: "Sexy French Pearl", species: "muskellunge", user: members[0], season: :fall, clarity: :stained, water_body: :lake, wind: :strong, tod: :midday, plat: :boat, ret: :jerk, loc: "Lake St. Clair", len: 110.0, wt: 9000, up: 95, photos: 3 },
  { lure: "Coltsniper Deep Sea Jig", variant: "Blue Sardine", species: "striped_bass", user: members[3], season: :fall, clarity: :clear, water_body: :river, wind: :moderate, tod: :dawn, plat: :boat, ret: :jerk, loc: "Cape Cod Canal", len: 88.0, wt: 7200, up: 58, photos: 2 }
]

notes = [
  "Slow twitch-pause on the first warm front — fish were stacked on the break.",
  "Burned it over grass and let it deflect; reaction bite all morning.",
  "Bottom-bumped the worm on a Texas rig, super slow.",
  "Found them schooling and it was a fish every cast for an hour.",
  "Cold front had them sluggish; the slow flutter sealed it."
]

catches = []
catch_specs.each_with_index do |spec, i|
  lure = lures.fetch(spec[:lure])
  variant = lure.variants.find_by!(name: spec[:variant])
  build = lure.builds.first
  c = Catch.find_or_create_by!(user: spec[:user], variant: variant, build: build, species: species.fetch(spec[:species]), location: spec[:loc]) do |catch_rec|
    catch_rec.season = spec[:season]
    catch_rec.clarity = spec[:clarity]
    catch_rec.water_body = spec[:water_body]
    catch_rec.wind = spec[:wind]
    catch_rec.time_of_day = spec[:tod]
    catch_rec.platform = spec[:plat]
    catch_rec.retrieve = spec[:ret]
    catch_rec.length_cm = spec[:len]
    catch_rec.weight_g = spec[:wt]
    catch_rec.note = notes[i % notes.size]
  end
  unless c.photos.attached?
    pool = SPECIES_PHOTOS.fetch(spec[:species], %w[bass_1.png])
    spec[:photos].times do |idx|
      filename = pool[idx % pool.size]
      path = CATCH_IMG.join(filename)
      c.photos.attach(io: File.open(path), filename: filename, content_type: "image/png") if File.exist?(path)
    end
  end
  catches << c
end

catch_specs.each_with_index do |spec, i|
  c = catches[i]
  voters = all_contributors.reject { |u| u == c.user }.first([ spec[:up] / 12, 1 ].max.clamp(1, all_contributors.size - 1))
  voters.each { |u| Upvote.find_or_create_by!(user: u, catch: c) }
end

comments_seed = [
  [ 0, members[1], "That GG finish is unreal in clear water." ],
  [ 0, members[3], "Lake Fork giants! Congrats." ],
  [ 4, admin, "Pike on a chatterbait — love it." ],
  [ 7, moderator, "Gorgeous rainbow — that canyon water is gin-clear." ],
  [ 11, members[3], "King salmon off Lake Michigan, what a fight!" ]
]
comments_seed.each do |(idx, user, body)|
  catches[idx].comments.find_or_create_by!(user: user, body: body)
end
puts "  catches: #{Catch.count}, upvotes: #{Upvote.count}, comments: #{Comment.count}"

# ---------------------------------------------------------------- Revisions (provenance)
def seed_revision(subject, user, summary, when_at)
  subject.revisions.find_or_create_by!(summary: summary) do |r|
    r.user = user
    r.created_at = when_at
  end
end

lures.values.each_with_index do |lure, i|
  seed_revision(lure, all_contributors[i % all_contributors.size], "Created this lure", 120.days.ago)
end
brands.values.each { |b| seed_revision(b, admin, "Created this brand", 200.days.ago) }
species.values.each { |s| seed_revision(s, moderator, "Created this species", 200.days.ago) }
shops.values.each { |s| seed_revision(s, members[0], "Created this shop", 150.days.ago) }
seed_revision(lures["Vision 110"], members[1], "Added a variant", 90.days.ago)
seed_revision(lures["Vision 110"], admin, "Corrected target depth", 30.days.ago)

# ---------------------------------------------------------------- Claims
# Verified ownership claims — these are what make a brand show as "claimed".
{ "Megabass" => "team@megabass.co.jp", "Rapala" => "owner@rapala.com", "Berkley" => "owner@berkley.com" }.each do |brand_name, email|
  claim = Claim.find_or_create_by!(claimable: brands[brand_name], user: admin) { |c| c.email = email }
  claim.verify! unless claim.status_verified?
end

Claim.find_or_create_by!(claimable: brands["Strike King"], user: members[0]) do |c|
  c.email = "owner@strikeking.com"
  c.status = :pending
end

# ---------------------------------------------------------------- Moderation queue (pending)
pending_catch = catches.last
ModerationItem.find_or_create_by!(subject: pending_catch, kind: :catch) { |m| m.submitter = pending_catch.user }

edit_rev = seed_revision(lures["KVD 1.5 Squarebill"], members[2], "Suggest: update blurb wording", 2.days.ago)
ModerationItem.find_or_create_by!(subject: edit_rev, kind: :edit) { |m| m.submitter = members[2] }

report = Report.find_or_create_by!(reportable: catches[1], user: members[4], reason: :wrong) { |r| r.note = "Looks like a spotted bass, not smallmouth." }
ModerationItem.find_or_create_by!(subject: report, kind: :report) { |m| m.submitter = members[4] }

pending_claim = Claim.find_by(claimable: brands["Strike King"])
if pending_claim
  ModerationItem.find_or_create_by!(subject: pending_claim, kind: :claim) do |m|
    m.submitter = members[0]
    m.mod_actionable = false
  end
end

ModerationItem.find_or_create_by!(subject: lures["Flat Side Pro"], kind: :catalog) { |m| m.submitter = members[0] }

puts "  moderation items: #{ModerationItem.count}, claims: #{Claim.count}, revisions: #{Revision.count}"

# ---------------------------------------------------------------- Recompute counters
Brand.find_each { |b| Brand.reset_counters(b.id, :lures) }
Species.find_each { |s| s.update_columns(catches_count: Catch.where(species_id: s.id).count) }
Lure.find_each { |l| l.update_columns(catches_count: l.catches.count) }
Variant.find_each { |v| v.update_columns(catches_count: v.catches.count) }
Catch.find_each { |c| c.update_columns(upvotes_count: c.upvotes.count, comments_count: c.comments.count) }

puts "Done. Sign in with admin@example.com / moderator@example.com / user1..5@example.com (password: 1)."
