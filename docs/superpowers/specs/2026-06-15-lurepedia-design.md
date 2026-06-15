# Lurepedia — Implementation Design

_Date: 2026-06-15_

## Overview

Lurepedia is a crowdsourced encyclopedia of fishing lures — **"every lure, proven by a catch."**
It helps anglers find lures and see real proof (catches) that a given lure catches a given
fish. The atomic unit of proof is a **catch**: photos + the conditions it was made in, tied to a
specific lure **variant** and a fish **species**, submitted by a user.

We are recreating the approved HTML/JS prototype (`Lurepedia.dc.html`) as a real, production-shaped
**Rails 8.1** application: SQLite, Propshaft, Importmap, Turbo, Stimulus, Active Storage,
Solid Queue/Cache/Cable. Built **in one pass** covering every screen.

### Core product principles (must come through)
1. **Proof-driven discovery** — everywhere a lure appears, show evidence it works (catch counts,
   species caught, example photos). Proven lures look more credible than unproven ones.
2. **Crowdsourcing surfaces when content is thin** — sparse pages pivot to friendly "be the first
   to add a catch/variant" prompts; rich pages push contribution CTAs to the margins.
3. **Contribution is account-gated** — signed-out visitors see "Sign in to contribute"; signed-in
   users see real action buttons. A header avatar/menu indicates signed-in state.

## Key decisions (locked)
- **Scope:** all screens in one pass (browse + contribution + moderation + admin + claims + leaderboard).
- **Languages:** `en`, `de`, `bg`, `ja` fully translated; `fr es el zh ru nl` wired with fallback to `en`.
- **i18n content model:** fixed taxonomy (species names, lure types, conditions, water types, UI
  strings) live as **I18n YAML keys**. User free-text (catch notes, lure/brand/shop blurbs,
  comments) is stored **as authored** and shown as-is (not auto-translated).
- **Auth:** Rails 8 built-in authentication generator (`has_secure_password` + bcrypt, session-based).
- **DB:** SQLite (dev/test/prod via the configured Rails 8 multi-db setup).
- **Images:** Active Storage (local disk in dev), `image_processing` variants.
- **Styling:** one design-token CSS file (custom properties) + component CSS, no CSS framework.
  Stimulus controllers for interactivity.

## Architecture

### URL & locale strategy (SEO)
- All content routes are nested under a locale scope: `/:locale/...` where locale ∈ the 10 codes.
- `scope "(:locale)"` with a default of `en`; `/` redirects to the visitor's best locale.
- `I18n.locale` set in an `around_action` from the URL; `default_url_options` injects `:locale` so
  every generated link keeps the active locale.
- **SEO:** each page renders `<link rel="alternate" hreflang="x">` for every locale + `x-default`,
  a canonical tag, localized `<title>`/`<meta description>`, and `lang`/`dir` on `<html>`.
  `sitemap.xml` lists every locale variant of every public URL. JSON-LD where it adds value
  (Product for lures, breadcrumbs).
- Slugs: human-readable, stable IDs (e.g. `megabass-vision-110`, `largemouth-bass`). Slug text is
  English/Latin and locale-independent (URLs don't change per language — only the locale prefix
  does), which keeps hreflang clusters clean.

### Translatable taxonomy
- Models carry a stable `key` (e.g. species `largemouth_bass`, lure type `crankbait`). Display names
  come from `t("species.#{key}.common")`, `t("lure_type.#{key}")`, etc., with `en` as fallback.
- A locale-aware sort uses the translated string for the active locale.
- The language switcher and per-user `locale`/`units`/`country` preferences drive presentation.

### Units
- `auto` (derived from locale: metric for de/bg/etc., imperial for en/en-US), `imperial`, `metric`.
- Canonical storage: lengths in **cm**, weights in **grams**, depth ranges in **cm**. A `Units`
  helper/service formats to the user's setting (cm↔in, g↔oz/lb, m↔ft).

## Data model (Rails schema)

Stable string slugs as the public identifier; integer PKs internally.

- **User** — `name, email, password_digest, role(enum: member/moderator/admin), country, locale,
  units(enum: auto/imperial/metric), bio`. `has_many :catches, :comments, :reports`.
- **Brand** — `slug, name, country, founded_year, blurb, claimed(bool)`. `has_many :lures`,
  `has_one :claim`. Active Storage `logo`.
- **Species** — `slug, key, scientific_name, water(enum: fresh/salt/both), habitat_key`.
  Common name + habitat via I18n. `has_many :catches`. Active Storage `photo`.
- **LureType** — small reference table: `key, water_default`. (Or a YAML-backed enum; will be a
  table so lures can `belongs_to`.) Names via I18n.
- **Lure** — `slug, brand_id, lure_type_id, model, water(enum), depth_min_cm, depth_max_cm,
  action(enum: suspending/floating/sinking/none), blurb, action_video_url`.
  `has_many :variants, :buy_links`; catches reached through variants. Counter cache `catches_count`.
- **Variant** — `lure_id, name, size_mm, weight_g, action`. Active Storage `photo`.
  `has_many :catches`.
- **Catch** — `user_id, variant_id (→lure), species_id, season, clarity, water_body, wind,
  time_of_day (enums), location, note, length_cm, weight_g, upvotes_count`. Active Storage
  `has_many_attached :photos`. `has_many :comments`.
- **Comment** — `catch_id, user_id, body`.
- **Shop** — `slug, name, url, blurb, promoted(bool), claimed(bool), lure_count`. `has_many
  :buy_links`, `has_one :claim`.
- **BuyLink** — `lure_id, shop_id, url`.
- **Claim** (polymorphic) — `claimable(Brand|Shop), user_id, email, status(pending/verified/rejected),
  verification_token, dns_verified_at`.
- **Report** (polymorphic) — `reportable(Catch|Lure|...), user_id(reporter), reason(enum), note`.
- **Edit/Provenance** — `Revision`: polymorphic `subject`, `user_id, summary, created_at` — powers
  the "History & ownership" timeline. Creator = first revision; owner = verified claim.
- **ModerationItem** — polymorphic `subject` (Catch, Revision, catalog submission, Claim, Report),
  `kind(enum: catch/edit/catalog/claim/report), submitter_id, status(pending/approved/rejected),
  mod_actionable(bool), reviewer_id, reviewed_at`. A unified review queue.
- **Upvote** — `user_id, catch_id` (unique) to back `upvotes_count`.

Counter caches and a few denormalized counts (brand.lures_count, species catch/lure counts) keep
index pages fast; recomputed in seeds.

## Screens → routes/controllers

| Screen | Route | Controller#action |
|---|---|---|
| Home = Lures index (sorted by catch count desc) | `/:locale` | `lures#index` |
| Lure detail (rich + sparse) | `/:locale/lures/:slug` | `lures#show` |
| Add a lure | `/:locale/lures/new` | `lures#new/create` |
| Species index / detail (tabs: lures/catches/leaderboard/history) | `/:locale/species[/:slug]` | `species#index/show` |
| Brands index / detail (tabs: lures/history) | `/:locale/brands[/:slug]` | `brands#index/show` |
| Catches index / detail | `/:locale/catches[/:id]` | `catches#index/show` |
| Add a catch (submit flow) | `/:locale/catches/new` | `catches#new/create` |
| Shops index (promoted pinned) / detail | `/:locale/shops` | `shops#index` |
| Search + filter results | `/:locale/search` | `search#index` |
| Leaderboard (species filter + metric toggle) | `/:locale/leaderboard` | `leaderboard#index` |
| Sign in / Sign up | `/:locale/session`, `/:locale/registration` | Rails 8 auth + `registrations` |
| My catches | `/:locale/my/catches` | `dashboard#catches` |
| Account settings (country/language/units) | `/:locale/settings` | `settings#edit/update` |
| Suggest edit (lure/brand/shop) | `/:locale/:type/:slug/suggest` | `revisions#new/create` |
| Claim brand/shop (3-step DNS TXT) | `/:locale/claims/...` | `claims#new/create/verify` |
| Report content | (modal POST) | `reports#create` |
| Moderation queue (mod+admin) | `/:locale/moderation` | `moderation#index/update` |
| Admin console (overview/people/activity) | `/:locale/admin` | `admin#...` |

Pundit-style policy gating (a lightweight `authorize`/`current_user` check; we'll use a small
policy object, not necessarily the gem) enforces role access. Contribution actions require login;
moderation requires moderator+; admin console + locked queue items require admin.

## Styling
- Tokens as CSS custom properties matching the prototype exactly: neutrals `#18181b #3f3f46
  #52525b #71717a #a1a1aa #d4d4d8 #e4e4e7 #f4f4f5 #fafafa`, accent indigo `#4f46e5` (light
  `#eef2ff`, border `#c7d2fe`), success `#0d7a5f/#ecfdf5/#a7f3d0`, amber promoted
  `#b45309/#fffbeb/#fde68a`, danger `#dc2626/#fef2f2/#fecaca`, medals gold/silver/bronze.
  Radii 5–14px + 999px pills; system font stack; shadows per spec.
- Reusable partials mirror the prototype components: `LureCard`, `CatchCard`, `Combobox`,
  `Provenance` (history & ownership), badges, pagination, tabs.
- Fully responsive (breakpoints 880/780/520px), accessible focus states, RTL-ready (none of the 10
  are RTL, but `dir` is wired).

## Interactivity (Stimulus)
- `combobox` (searchable select), `header-search` (expand-over-nav + filter dropdown),
  `dropdown` (avatar menu, language switcher with circular flags), `tabs`, `modal` (sign-in, report,
  video), `image-upload` (multi-file preview, remove, set-cover), `gallery` (catch photo carousel),
  `claim-verify` (copy TXT + verify), `flash`.
- Turbo Frames/Streams for filter results, pagination, moderation actions (approve/reject/undo),
  upvotes, and comment posting.

## Seeds
- Users: `admin@example.com` (admin), `moderator@example.com` (moderator), 5 members
  (`user1..5@example.com`), all password `1`. Realistic names/countries/locales.
- Catalog from the prototype's sample data: brands (Megabass, Rapala, Strike King, Z-Man, Booyah,
  Berkley…), species (largemouth/smallmouth bass, pike, walleye, perch, musky, bluegill, rainbow
  trout — incl. an unproven species), lure types, lures (incl. one unproven), variants, shops
  (incl. promoted), buy links, catches with conditions/notes, comments, revisions, a few reports
  and pending moderation items, claims (one verified, one pending).
- **Lure variant images:** the 12 files in `allthelures/db/seeds/lure_images/` (copied into the
  repo's `db/seeds/lure_images/`), attached via Active Storage.
- **Catch photos:** the 7 Desktop `PNG image*.png` files (copied into `db/seeds/catch_images/`),
  attached to catches (some catches multi-photo).
- Species photos use representative crops/placeholders; brands use initials when no logo.
- Translations seeded for `en/de/bg/ja`: all UI strings + every species common name + habitat +
  every lure type + condition enums.

## i18n / SEO deliverables
- `config/locales/{en,de,bg,ja,fr,es,el,zh,ru,nl}.yml` (last six = fallback skeleton).
- `config.i18n.fallbacks = true`, default `en`, `available_locales` = the 10.
- hreflang + canonical + localized meta in the layout; `sitemap.xml`; `<html lang dir>`.

## Testing
- Model tests: associations, enums, units conversion, counter caches, slug generation, policy gating.
- Helper/service tests: `Units` formatting (cm↔in, g↔oz/lb), locale taxonomy lookup + fallback.
- Request/integration tests: locale routing + redirect, hreflang presence, auth gating (signed-out
  vs member vs moderator vs admin), add-a-catch happy path, moderation approve/reject, search/filter,
  leaderboard ranking by each metric, claim DNS verify flow.
- System tests (Capybara) for the key interactive flows: combobox filter, expanding search, image
  upload preview, tabs, sign-in modal, report modal.

## Out of scope (this pass)
- Real OAuth (Google button is email/password-backed or stubbed), real DNS lookups (verification is
  simulated against the stored token), real payment for promoted shops, auto-translation of
  user free-text, email delivery.
