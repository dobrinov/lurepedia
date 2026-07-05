# Brand catalog imports

Real-brand catalogs are imported from scraped JSON via `bin/rails runner`, not
`db/seeds.rb` (seeds stay demo-only). The scrape itself is bespoke per brand
site (each publishes its range differently — see the per-brand recipes in the
session memory / past import notes); what's standardized is the JSON handed to
the importer.

## Import a catalog

```bash
bin/rails runner script/import/import_catalog.rb path/to/brand.json
```

Idempotent (`find_or_create_by!` on natural names) — safe to re-run after a
partial failure. Photos attach only when missing, from a local `file` (path
relative to the JSON) or a downloaded `image` URL.

### JSON format

```jsonc
{
  "brand": { "name": "...", "country": "JP", "website": "...", "founded_year": 1996, "blurb": "..." },
  "lures": [
    {
      "model": "Tide Minnow Slim",
      "lure_type": "jerkbait",            // LureType key
      "blurb": "...",
      "video": "https://...",             // optional
      "builds": [
        { "name": "120", "length_mm": 120, "weight_g": 13.0,
          "depth_min_cm": 60, "depth_max_cm": 100,
          "action": "floating", "water": "salt", "position": 0 }
      ],
      "colors": [
        { "name": "Midnight Black",
          "uv_glow": false,
          "file": "images/abc.jpg",       // or "image": "https://..."
          "builds": [ "120", "140" ]      // ← availability (optional, see below)
        }
      ]
    }
  ]
}
```

### The `colors[].builds` availability list

Feeds the **open-world** `variant_builds` matrix: it confirms which builds
(sizes) carry the color.

- **Omit it** when the source site doesn't publish per-size color charts — the
  color then stays "availability unknown" and displays under every build,
  which is the honest state. Never guess it.
- Include it only from real per-size data (per-size color pages, size×color
  shop variants, configurable-product option intersections, …).
- Names must match the lure's `builds[].name` exactly; misses are reported and
  skipped, never invented.
- Only worth scraping for lures with **more than one build** — for
  single-build lures, confirmed and unknown render identically.

## Backfill availability for existing records

For confirming availability after the fact (records already imported without
per-color `builds`):

```bash
bin/rails runner script/import/backfill_variant_builds.rb availability.json
# format: [ { "brand", "model", "build", "colors": [names] } ]
```

Additive, idempotent, reports unmatched names. Brand-name drift between
environments is handled by `BRAND_ALIASES` in the script.

## Prod runs

sftp the JSON (+ images or let the script download) and run **as the rails
user** — never root, or SQLite/storage ownership breaks the web process:

```bash
fly ssh console -a lurepedia -C "su rails -c 'cd /rails && bin/rails runner /tmp/import_catalog.rb /tmp/brand.json'"
```

`/tmp` on the machine is wiped by deploys/restarts; re-upload and re-run.
Photo-heavy imports OOM the 1GB machine — bump to 2048MB first
(`fly machine update <id> --vm-memory 2048 -y`), scale back after.
Availability-only backfills are tiny and safe as-is.
