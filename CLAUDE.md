# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Lurepedia is a Rails 8.1 community wiki for fishing lures: a crowd-sourced catalog of lures (brand → lure → variant) cross-referenced with user-logged catches and the conditions under which each lure proved itself. Browsing is public; contributing requires a login and (for non-admins) moderation. The stack is the Rails 8 "omakase" default: SQLite, Propshaft, importmap, Hotwire (Turbo + Stimulus), Solid Queue/Cache/Cable, no Node build step. Ruby 4.0.1.

## Commands

```bash
bin/setup                # install gems, prepare DB, (re)start dev server
bin/dev                  # run the server (alias for bin/rails server)
bin/rails test           # run all non-system tests
bin/rails test test/models/lure_test.rb              # single file
bin/rails test test/models/lure_test.rb:42           # single test by line
bin/rails test:system    # system tests (Capybara + Selenium); not run in bin/ci by default
bin/rails db:seed         # load db/seeds.rb (idempotent; attaches seed images)
bin/rails db:seed:replant # wipe + reseed
bin/ci                   # full local CI: rubocop, bundler-audit, importmap audit, brakeman, tests, seed check
bin/rubocop              # lint (rubocop-rails-omakase house style)
bin/brakeman             # security static analysis
```

Tests run in parallel and load `fixtures :all`. There is no separate JS test suite or asset build — importmap serves JS directly.

### Browser research & automation

When a task needs a real browser — researching live web pages, rendering JS-heavy sites, or verifying built features in the running app — run `agent-browser skills get core` first to load the browser skill, then drive the browser through it.

## Deployment

Production runs on **Fly.io** (app `lurepedia`, region `lhr`), served at `https://lurepedia.com` / `www.lurepedia.com` (TLS via Fly certs) and `https://lurepedia.fly.dev`. Config lives in `fly.toml`. Kamal is **not** used — there is no `config/deploy.yml` or `.kamal/`.

```bash
fly deploy -a lurepedia --ha=false     # build + release (ha=false keeps it to one machine)
fly logs -a lurepedia                  # tail logs
fly ssh console -a lurepedia           # shell on the machine
fly machine exec <id> "<cmd>" -a lurepedia   # one-off command; pass --timeout for slow Rails boots
```

Key facts to respect:

- **Single always-on machine.** SQLite can't be shared across machines, so the app must stay at **one** machine (`min_machines_running = 1`, `auto_stop_machines = "off"`). Solid Queue runs inside Puma (`SOLID_QUEUE_IN_PUMA=true`), so a stopped machine runs no jobs — never enable auto-stop or scale count > 1.
- **The database is a Fly volume** (`lurepedia_data` mounted at `/rails/storage`) holding all four SQLite DBs (primary, cache, queue, cable). It survives deploys; destroying the volume wipes prod. Fly volume snapshots are on (5-day retention) as the backup.
- **Migrations** run automatically on boot via `bin/docker-entrypoint` (`db:prepare`). Note `db:prepare` runs `db/seeds.rb` on first DB creation — seeds are guarded to a no-op outside development/test (`Rails.env.local?`), so prod stays clean.
- **TLS terminates at Fly's edge**; the container speaks plain HTTP. `production.rb` sets `assume_ssl` + `force_ssl` (secure cookies, HSTS) and pins `config.hosts`. Thruster listens on **8080** (`HTTP_PORT`), not the privileged port 80, because the container runs as non-root — `fly.toml`'s `internal_port` and health check must match.
- **Image variants need ImageMagick** (`variant_processor = :mini_magick`); the Dockerfile installs `imagemagick` alongside `libvips`.
- **`fly ssh console` runs as root, but Puma runs as `rails` (uid 1000).** Any console/runner work that writes to Active Storage creates `root:root` shard dirs under `/rails/storage` that the web process can't mkdir into. Uploads then fail `Errno::EACCES` *after* the DB row commits, leaving blob/variant records with no file — images 302 then 404, and the breakage looks random. Run such maintenance as the rails user (`su rails -c '...'`) or finish with `chown -R rails:rails /rails/storage`; to repair, chown then destroy the record-without-file blobs/variant records so they regenerate.
- `RAILS_MASTER_KEY` is a Fly secret (`fly secrets set`), never committed.
- **DNS** is on Namecheap (BasicDNS); apex + `www` use A/AAAA records to the app's Fly IPs.

## Architecture

### Domain model

The catalog is **Brand → Lure → two independent axes**: `Variant` is a color/finish (name, photo, `uv_glow`) and `Build` is a physical size/spec (name like "140 FLYER", `length_mm`, `weight_g`, depth range in cm, buoyancy `action`, `water`). A lure also has a `lure_type` (spoon, jerkbait, …) and an optional explicit `default_variant`; `Lure#primary_variant` resolves it (explicit pick, else first-added) without shadowing the association.

**Color↔build availability is open-world.** The `variant_builds` join records which builds a color is *confirmed* to come in; a variant with **no** rows means "availability unknown — show the color under every build", never "available nowhere". `Variant#available_builds` resolves this; views must intersect it with the visibility-filtered build list (see `lures/show`). Availability edits ride `commit_edit` as a `build_ids` array; the `/variations` JSON ships `build_ids: null | [ids]` per color and the catch picker narrows builds by the chosen color (one-directional — colors are never filtered by build). Never validate catches against the matrix: a catch on an "unavailable" combo is evidence the matrix is wrong.

A `Catch` belongs to a `Variant` (and a `Species`), plus an **optional** `Build` that must belong to the same lure; a lure's catches reach it `through: :variants`. `catches_count` on `Lure` is a denormalized counter maintained by `Catch` callbacks (`bump_lure_counter`/`drop_lure_counter`) — a lure is "proven" when it has > 0 catches. `Catch` carries the condition enums (`season`, `clarity`, `water_body`, `wind`, `time_of_day`) that power discovery.

Other domain pieces: `Shop`/`BuyLink` (where to buy; shops list delivery-to-viewer-country first), `Comment`/`Upvote`/`Report` (community on catches), `Claim` (brand/lure/shop ownership: claimant leaves an email + message, an admin decides it in the moderation queue; a verified claim's holder edits that listing without review), `Revision` (polymorphic edit history), `ModerationItem` (the review queue), `LureLink` (symmetric "similar lures" cross-reference, usually cross-brand: one row per pair stored lower-id-first, a `Publishable` catalog entry whose direct-add is **admin-only** because a link touches two brands). Upload-time look-alike proposals come from `ColorSignature` fingerprints stored in blob metadata by `TileBackgroundAnalyzer` and ranked by `SimilarLureSuggestions` — a suggestion engine only; nothing links without a human tick.

**Canonical units are metric** — depths and catch lengths in cm, build lengths in **mm** (`length_mm`, by convention — don't "fix" it to cm), weights in grams. Never format measurements inline; always go through `Units` (`app/services/units.rb`), which converts to the viewer's preferred system (`:auto` resolves to imperial only for the `en` locale).

### Cross-cutting concerns (read these before touching controllers/models)

- `Authentication` (`app/controllers/concerns/`) — custom session auth (no Devise). `Current.session`/`Current.user` (`ActiveSupport::CurrentAttributes`) hold the actor. Public-by-default: there is no global auth filter; gate actions explicitly.
- `Authorization` — plain-Ruby policy objects (no Pundit). `policy(:catch)` or `policy(record)` infers `<Class>Policy`. Defaults in `ApplicationPolicy`: reads public, writes need login. Controllers gate with `require_login` / `require_moderator` / `require_admin`; `NotAuthorized` is rescued into a redirect/403.
- `Editable` — the contribution model. `commit_edit` applies a change directly (+ a `Revision`) for admins and the record's verified brand/shop owner, but for everyone else creates a `Revision` plus a pending `ModerationItem` instead of mutating the record; it returns true/false so callers can chain follow-up work. Edit affordances read "Edit" for direct editors, "Suggest an edit" for others. Most write paths should funnel through this rather than calling `update` directly.
- `Paginatable` — `paginate(scope, per:)` returns a `Page` struct rendered by `shared/_pagination`. Used app-wide instead of a gem.
- `Sluggable` (model concern) — `to_param` returns the slug; auto-generates a unique slug from `slug_source` (override per model). Look up records by slug, not id.

Discovery/listing logic lives in **query objects** under `app/queries/` (`LureFilter`, `LeaderboardQuery`), not in controllers. `LureFilter` is the heart of search/browse: it whitelists params via `ATTRS`, maps depth bands to cm ranges, and builds the removable filter pills. Buoyancy, depth and water live on builds, so a lure matches when **any** of its builds does; the default sort is recently-updated (`proven` is an explicit sort option).

### Roles & moderation

`User#role` is `member`/`moderator`/`admin`. Moderators can action most `ModerationItem`s; **claims and new catalog entries require an admin** (`ModerationItem#actionable_by?` / `mod_actionable?`), and nobody actions their own submission. Approving a suggested **edit** is what lands it: `approve!` applies the revision's changeset to the record (and `reject!`/`undo!` roll an applied one back). Approving a **claim** mirrors the verdict onto the claim itself (`approve!`/`reject!`/`reopen!`), which is what confers or revokes owner rights. New catalog entries and catches just flip status — they were created live and gated by `Publishable` visibility until approved.

### Localization

The app is multi-locale (15 locales in `config/locales/`; `en` is default and the only imperial one). Routes are wrapped in an optional `(:locale)` scope — bare `/` redirects to the default locale. `ApplicationController#switch_locale` resolves locale from param → user pref → cookie → default and sets `default_url_options[:locale]`, so every generated URL is locale-prefixed. All user-facing strings go through `I18n.t`; enum/condition labels are translated by key (e.g. `condition.season.spring`). When adding a UI string, add it to **all** locale files.

### Frontend

Server-rendered ERB + Hotwire. Stimulus controllers live in `app/javascript/controllers/` and are registered via importmap (`app/javascript/controllers/index.js`) — there is no bundler. Reusable UI lives in `app/views/shared/` partials (`_lure_card`, `_catch_card`, `_provenance`, `_combobox`, `_async_combobox`, `_pagination`). Large filter dropdowns use the async combobox backed by `FilterOptionsController` (`/options/species`, `/options/brands`).

`/design-system` is a living styleguide that renders the real shared partials against in-memory sample objects from `DesignSystem::SampleData` (`app/models/design_system/`) — no DB access. When you change a shared partial's interface, keep its `SampleData` stub in sync or the styleguide breaks.

## Conventions

- Match the omakase rubocop style (`bin/rubocop` is enforced in CI). Note the house spacing inside brackets (`[ a, b ]`).
- New features in this repo follow a spec → plan → implement flow; design specs live in `docs/superpowers/specs/` and plans in `docs/superpowers/plans/`.
- Prefer the existing concern/query/policy patterns over reaching for a gem — this app deliberately uses hand-rolled auth, authorization, and pagination.
