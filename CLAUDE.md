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

## Architecture

### Domain model

The catalog is three levels: **Brand → Lure → Variant**. A `Catch` belongs to a `Variant` (and a `Species`), so a lure's catches reach it `through: :variants`. `catches_count` on `Lure` is a denormalized counter maintained by `Catch` callbacks (`bump_lure_counter`/`drop_lure_counter`) — a lure is "proven" when it has > 0 catches. `Catch` carries the condition enums (`season`, `clarity`, `water_body`, `wind`, `time_of_day`) that power discovery; `Lure` carries catalog enums (`water`, `action`) and a depth range in centimetres.

Other domain pieces: `Shop`/`BuyLink` (where to buy), `Comment`/`Upvote`/`Report` (community on catches), `Claim` (brand/lure ownership via simulated DNS-TXT token), `Revision` (polymorphic edit history), `ModerationItem` (the review queue).

**Canonical units are metric** — lengths/depths stored in cm, weights in grams. Never format measurements inline; always go through `Units` (`app/services/units.rb`), which converts to the viewer's preferred system (`:auto` resolves to imperial only for the `en` locale).

### Cross-cutting concerns (read these before touching controllers/models)

- `Authentication` (`app/controllers/concerns/`) — custom session auth (no Devise). `Current.session`/`Current.user` (`ActiveSupport::CurrentAttributes`) hold the actor. Public-by-default: there is no global auth filter; gate actions explicitly.
- `Authorization` — plain-Ruby policy objects (no Pundit). `policy(:catch)` or `policy(record)` infers `<Class>Policy`. Defaults in `ApplicationPolicy`: reads public, writes need login. Controllers gate with `require_login` / `require_moderator` / `require_admin`; `NotAuthorized` is rescued into a redirect/403.
- `Editable` — the contribution model. `commit_edit` applies an admin's change directly (+ a `Revision`), but for everyone else creates a `Revision` plus a pending `ModerationItem` instead of mutating the record. Edit affordances read "Edit" for admins, "Suggest an edit" for others. Most write paths should funnel through this rather than calling `update` directly.
- `Paginatable` — `paginate(scope, per:)` returns a `Page` struct rendered by `shared/_pagination`. Used app-wide instead of a gem.
- `Sluggable` (model concern) — `to_param` returns the slug; auto-generates a unique slug from `slug_source` (override per model). Look up records by slug, not id.

Discovery/listing logic lives in **query objects** under `app/queries/` (`LureFilter`, `LeaderboardQuery`), not in controllers. `LureFilter` is the heart of search/browse: it whitelists params via `ATTRS`, maps depth bands to cm ranges, and builds the removable filter pills.

### Roles & moderation

`User#role` is `member`/`moderator`/`admin`. Moderators can action most `ModerationItem`s; **claims and new catalog entries require an admin** (`ModerationItem#actionable_by?` / `mod_actionable?`). The moderation queue (`ModerationController`) only flips item status — approving does not itself re-apply the change, since non-admin edits already wrote their `Revision` at submission time.

### Localization

The app is multi-locale (10 locales in `config/locales/`; `en` is default and the only imperial one). Routes are wrapped in an optional `(:locale)` scope — bare `/` redirects to the default locale. `ApplicationController#switch_locale` resolves locale from param → user pref → cookie → default and sets `default_url_options[:locale]`, so every generated URL is locale-prefixed. All user-facing strings go through `I18n.t`; enum/condition labels are translated by key (e.g. `condition.season.spring`). When adding a UI string, add it to **all** locale files.

### Frontend

Server-rendered ERB + Hotwire. Stimulus controllers live in `app/javascript/controllers/` and are registered via importmap (`app/javascript/controllers/index.js`) — there is no bundler. Reusable UI lives in `app/views/shared/` partials (`_lure_card`, `_catch_card`, `_provenance`, `_combobox`, `_async_combobox`, `_pagination`). Large filter dropdowns use the async combobox backed by `FilterOptionsController` (`/options/species`, `/options/brands`).

`/design-system` is a living styleguide that renders the real shared partials against in-memory sample objects from `DesignSystem::SampleData` (`app/models/design_system/`) — no DB access. When you change a shared partial's interface, keep its `SampleData` stub in sync or the styleguide breaks.

## Conventions

- Match the omakase rubocop style (`bin/rubocop` is enforced in CI). Note the house spacing inside brackets (`[ a, b ]`).
- New features in this repo follow a spec → plan → implement flow; design specs live in `docs/superpowers/specs/` and plans in `docs/superpowers/plans/`.
- Prefer the existing concern/query/policy patterns over reaching for a gem — this app deliberately uses hand-rolled auth, authorization, and pagination.
