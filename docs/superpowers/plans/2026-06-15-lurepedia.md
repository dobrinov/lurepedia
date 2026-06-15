# Lurepedia Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the Lurepedia crowdsourced fishing-lure encyclopedia as a production-shaped, multilingual, SEO-optimized Rails 8.1 app recreating the approved prototype's screens.

**Architecture:** Server-rendered Rails 8 (Propshaft + Importmap + Turbo + Stimulus), SQLite, Active Storage. Locale-prefixed URLs (`/:locale/...`) with hreflang/canonical SEO. Fixed taxonomy (species/lure-type/condition names + UI) in I18n YAML (en/de/bg/ja full; 6 more fallback). Three roles (member/moderator/admin) with policy gating. Design tokens as CSS custom properties matching the shadcn-style prototype.

**Tech Stack:** Rails 8.1.3, Ruby 4.0.1, SQLite, bcrypt, Active Storage + image_processing, Turbo/Stimulus, Minitest + Capybara.

---

## Conventions for every task
- TDD where it has logic value (models, services, policies, requests). Pure-markup view tasks are verified by request specs asserting key content + a manual smoke check.
- Run `bin/rails test` (and `bin/rails test:system` where noted) before each commit.
- Commit at the end of each task with a `feat:`/`test:`/`chore:` message ending with the Co-Authored-By trailer.
- Work on branch `lurepedia-build` (already created).

---

## Task 1: Gems, auth scaffold, base config

**Files:**
- Modify: `Gemfile`
- Create: auth via `bin/rails generate authentication`
- Modify: `config/application.rb`, `config/initializers/locale.rb` (create)

- [ ] **Step 1:** Add to `Gemfile`: `gem "bcrypt", "~> 3.1.7"`. Run `bundle install`.
- [ ] **Step 2:** Generate Rails 8 auth: `bin/rails generate authentication` (creates `User`, `Session`, `Current`, `SessionsController`, `PasswordsController`, concerns `Authentication`). Run `bin/rails db:migrate`.
- [ ] **Step 3:** Add to the generated `User` migration follow-up (new migration `add_profile_to_users`): `role:integer (default 0), name:string, country:string, locale:string (default "en"), units:integer (default 0), bio:text`. Migrate.
- [ ] **Step 4:** In `config/application.rb` set `config.i18n.available_locales = %i[en de bg ja fr es el zh ru nl]`, `config.i18n.default_locale = :en`, `config.i18n.fallbacks = true`.
- [ ] **Step 5:** Create `config/initializers/locale.rb` requiring i18n fallbacks default to `:en`.
- [ ] **Step 6:** Model test `test/models/user_test.rb`: assert `role` enum `{member:0, moderator:1, admin:2}`, `units` enum `{auto:0, imperial:1, metric:2}`, `has_secure_password`. Add the enums to `app/models/user.rb`. Run tests green.
- [ ] **Step 7:** Commit.

---

## Task 2: Locale routing + SEO layout foundation

**Files:**
- Modify: `config/routes.rb`
- Modify: `app/controllers/application_controller.rb`
- Create: `app/helpers/seo_helper.rb`
- Modify: `app/views/layouts/application.html.erb`
- Test: `test/integration/locale_routing_test.rb`

- [ ] **Step 1:** Write `test/integration/locale_routing_test.rb`: GET `/` redirects to `/en`; GET `/de` sets `I18n.locale == :de` (assert `<html lang="de">` in body); an unknown locale `/xx` 404s or falls to default; links generated on a localed page keep the prefix.
- [ ] **Step 2:** In `routes.rb`, wrap all app routes in `scope "(:locale)", locale: /#{I18n.available_locales.join("|")}/ do ... end`; add `root` redirect to `/#{I18n.default_locale}` and a localized root → `lures#index`.
- [ ] **Step 3:** In `ApplicationController`: `around_action :switch_locale` (sets `I18n.locale` from `params[:locale]` with fallback), `def default_url_options = { locale: I18n.locale }`.
- [ ] **Step 4:** `SeoHelper`: `hreflang_tags` (one `<link rel="alternate" hreflang>` per available locale via `url_for(locale: l)` + `x-default`), `canonical_tag`, `page_title`/`meta_description` helpers reading from content or i18n.
- [ ] **Step 5:** Update layout `<html lang="<%= I18n.locale %>" dir="ltr">`, `<head>` renders `hreflang_tags`, `canonical_tag`, title/description, and the design-token stylesheet link.
- [ ] **Step 6:** Run integration test green. Commit.

---

## Task 3: Design tokens + base CSS + layout chrome

**Files:**
- Create: `app/assets/stylesheets/tokens.css`, `application.css` (import), `components.css`, `layout.css`
- Create: `app/views/layouts/_header.html.erb`, `_footer.html.erb`, `_flash.html.erb`
- Create header Stimulus controllers (Task 9 wires behavior; markup here)

- [ ] **Step 1:** `tokens.css` — `:root` custom properties for the full palette (neutrals `#18181b … #fafafa`, accent `--accent:#4f46e5` + `--accent-bg:#eef2ff` + `--accent-border:#c7d2fe`, success `#0d7a5f/#ecfdf5/#a7f3d0`, amber promoted `#b45309/#fffbeb/#fde68a`, danger `#dc2626/#fef2f2/#fecaca`, medal gold/silver/bronze), radii (`--r-sm:6px … --r-lg:14px`, `--r-pill:999px`), font stack, shadows (`--shadow-modal:0 24px 60px rgba(24,24,27,.25)` etc.), container `--maxw:1200px`.
- [ ] **Step 2:** `layout.css` — sticky blurred header (60px, backdrop-filter blur(12px), 82% white, bottom border), `.container{max-width:var(--maxw);margin:0 auto;padding:0 24px}`, footer grid (`1.6fr 1fr 1fr 1fr`, responsive 780/520px), main spacing.
- [ ] **Step 3:** `components.css` — `.card`, `.btn`/`.btn-primary`/`.btn-ghost`, `.badge` variants (catch/edit/catalog/claim/report + role badges + promoted), `.chip`/`.chip-active`, `.pill`, `.tab`/`.tab-active`, `.input`/`.combobox`, `.avatar`, medal ranks, grids (`.grid-cards` auto-fill minmax(220px,1fr) gap 18px).
- [ ] **Step 4:** `_header.html.erb` — wordmark (`<span style="font-weight:300">lure</span><span style="font-weight:800">pedia</span>` linking to localed root), nav links (Lures/Species/Catches) with `data-header-search-target`, expanding search input + filter dropdown markup, language switcher (circular flag + chevron, dropdown of 10 langs with native names), avatar menu (signed-in: initials, role badge, email, menu items Report a catch / My catches / Account settings / staff Review queue + Admin console / Log out / demo role switch) or "Sign in" button.
- [ ] **Step 5:** `_footer.html.erb` — wordmark + tagline, columns Discover (Species/Brands/Catches/Leaderboard/Shops), Contribute (Add a catch/Claim a brand/Claim a shop), About (How it works/Moderation/Guidelines), copyright.
- [ ] **Step 6:** `_flash.html.erb`. Wire all three partials into the layout. Manual smoke: `bin/rails s`, load `/en`, header+footer render. Commit.

---

## Task 4: Taxonomy + i18n YAML (en/de/bg/ja + fallback skeleton)

**Files:**
- Create: `config/locales/en.yml`, `de.yml`, `bg.yml`, `ja.yml`, and skeleton `fr/es/el/zh/ru/nl.yml`
- Create: `app/models/lure_type.rb`, `app/models/concerns/translatable_taxonomy.rb`
- Test: `test/models/lure_type_test.rb`, `test/helpers/taxonomy_helper_test.rb`

- [ ] **Step 1:** Define namespaced keys in `en.yml`: `species.{key}.common` + `.habitat` for each species; `lure_type.{key}`; `condition.season.*`, `condition.clarity.*`, `condition.water_body.*`, `condition.wind.*`, `condition.time_of_day.*`, `water.{fresh,salt,both}`, `action.{suspending,floating,sinking,none}`; plus UI strings (`nav.*`, `home.*`, `lure.*`, `catch.*`, `species.*`, `brand.*`, `shop.*`, `search.*`, `leaderboard.*`, `moderation.*`, `admin.*`, `auth.*`, `settings.*`, `units.*`, `common.*`).
- [ ] **Step 2:** Translate the same keys fully in `de.yml`, `bg.yml`, `ja.yml` (German, Bulgarian, Japanese). Reference the prototype Bulgarian screenshot wording for search filters (Филтри, Вид, Тип, Марка, Сезон, Водоем, Бистрота, Вятър, Солена вода, Търси).
- [ ] **Step 3:** Skeleton `fr/es/el/zh/ru/nl.yml` with just `en: {}`-equivalent top keys empty so fallback to en works (or a thin file; fallbacks fill the rest).
- [ ] **Step 4:** `LureType` model: `key` column, `name` via `I18n.t("lure_type.#{key}")`. `TranslatableTaxonomy` concern: `translated(attr)` helper + `display_name`.
- [ ] **Step 5:** Tests: `LureType#name` returns translated string for active locale and falls back to en for `:fr`. Taxonomy helper test for species common-name lookup. Run green. Commit.

---

## Task 5: Catalog schema + models (brands, species, lure types, lures, variants, shops, buy links)

**Files:**
- Migrations under `db/migrate/`
- Models `app/models/{brand,species,lure_type,lure,variant,shop,buy_link}.rb`
- Test: `test/models/*` for each

- [ ] **Step 1:** Write model tests first for associations + slug + counters: `Lure belongs_to :brand, :lure_type; has_many :variants; has_many :catches, through: :variants`; `Species has_many :catches`; `Brand has_many :lures` with `lures_count`; `Shop has_many :buy_links`; slug auto-generated from name/model; `Lure#depth_range` returns `{min_cm,max_cm}`.
- [ ] **Step 2:** Generate migrations per the spec data model (Brand, Species, LureType, Lure, Variant, Shop, BuyLink) with the exact columns from the spec (enums as integers, counter cache columns, Active Storage handled by attachments). Add `slug` unique indexes.
- [ ] **Step 3:** Implement models: enums (`water`, `action`), `has_one_attached`/`has_many_attached`, `belongs_to`/`has_many`, `before_validation` slug generation (parameterize), validations, scopes (`Lure.proven`, `Lure.by_catch_count`).
- [ ] **Step 4:** Run model tests green. Commit.

---

## Task 6: Contribution/community schema + models (catches, comments, upvotes, claims, reports, revisions, moderation items)

**Files:**
- Migrations; models `app/models/{catch,comment,upvote,claim,report,revision,moderation_item}.rb`
- Test: `test/models/*`

- [ ] **Step 1:** Tests: `Catch belongs_to :user,:variant,:species; has_many :comments; has_many_attached :photos; has_one :lure, through: :variant`; condition enums; `length_cm/weight_g` numeric. `Upvote` unique per (user,catch) and maintains `catches.upvotes_count`. `Claim` polymorphic with `status` enum + `verification_token` auto-gen. `Report` polymorphic + `reason` enum. `Revision` polymorphic ordered by created_at. `ModerationItem` polymorphic + `kind`/`status` enums + `mod_actionable` scope.
- [ ] **Step 2:** Migrations with polymorphic refs (`claimable`, `reportable`, `subject`) and indexes; counter caches.
- [ ] **Step 3:** Implement models incl. `Claim#generate_token` (`lurepedia-verify=lp_#{kind}_#{slug}_#{hex}`), `Claim#verify!` (simulated: compares submitted token, sets `dns_verified_at`, status verified). `ModerationItem.pending`, `.actionable_by(user)`.
- [ ] **Step 4:** Run green. Commit.

---

## Task 7: Units service + provenance/leaderboard query objects

**Files:**
- Create: `app/services/units.rb`, `app/helpers/units_helper.rb`
- Create: `app/queries/leaderboard_query.rb`
- Test: `test/services/units_test.rb`, `test/queries/leaderboard_query_test.rb`

- [ ] **Step 1:** Tests for `Units`: `format_length(54.6, :imperial) == "21.5 in"`, `:metric == "54.6 cm"`; `format_weight(2359, :imperial)`→lb/oz, `:metric`→g/kg; `format_depth(range, system)`→ft or m; `:auto` derives from locale (en→imperial, de/bg/ja→metric).
- [ ] **Step 2:** Implement `Units` (canonical cm/g) + `UnitsHelper#fmt_length/weight/depth(value, user:)` reading `current_user&.units || :auto`.
- [ ] **Step 3:** Tests for `LeaderboardQuery.new(species: nil|species, metric: :catches|:upvotes|:length).rows` → array of `{user, catches, upvotes, best_length_cm, species_count}` sorted by metric, ties broken by upvotes; species filter restricts to that species.
- [ ] **Step 4:** Implement query (group catches by user, aggregate). Run green. Commit.

---

## Task 8: Policies + authorization gating

**Files:**
- Create: `app/policies/application_policy.rb` + per-resource policies, `app/controllers/concerns/authorization.rb`
- Test: `test/policies/*`

- [ ] **Step 1:** Tests: signed-out cannot create catch/lure/etc; member can contribute but not moderate; moderator can act on `mod_actionable` items but not claims/admin; admin can do all. `authorize!`/`policy(record)` helper raises/redirects when denied.
- [ ] **Step 2:** Implement a lightweight policy layer (plain Ruby objects, no gem): `ApplicationPolicy`, `CatchPolicy`, `LurePolicy`, `ModerationPolicy`, `AdminPolicy`, `ClaimPolicy`. `Authorization` concern with `require_login`, `require_moderator`, `require_admin` before_actions + a `policy` helper.
- [ ] **Step 3:** Run green. Commit.

---

## Task 9: Stimulus controllers (interactivity)

**Files:**
- Create under `app/javascript/controllers/`: `combobox_controller.js`, `header_search_controller.js`, `dropdown_controller.js`, `tabs_controller.js`, `modal_controller.js`, `image_upload_controller.js`, `gallery_controller.js`, `claim_verify_controller.js`, `flash_controller.js`
- Modify: `app/javascript/controllers/index.js` (pin/register), `config/importmap.rb` if needed
- Test: `test/system/interactivity_test.rb`

- [ ] **Step 1:** Implement `combobox` (searchable select: open/close, filter input, keyboard, pick → hidden field + dispatch change), matching the prototype Combobox behavior/markup classes.
- [ ] **Step 2:** `header_search` (focus expands input over nav — toggle a class that hides nav + grows width 330→620px; opens filter dropdown; `nav()`/navigation closes it; no autocomplete per chat feedback).
- [ ] **Step 3:** `dropdown` (avatar menu + language switcher: toggle, outside-click close ignoring inner clicks), `tabs` (species/brand detail), `modal` (sign-in/report/video open/close + backdrop), `image_upload` (multi-file: preview grid, remove, set-cover, writes to file input), `gallery` (catch carousel numbered thumbs), `claim_verify` (copy token to clipboard + simulated verify), `flash` (auto-dismiss).
- [ ] **Step 4:** Register all in `index.js`. System test: combobox filters, header search expands, tabs switch, modal opens, image upload shows previews. Run `bin/rails test:system` for these. Commit.

---

## Task 10: Reusable view partials (cards & components)

**Files:**
- Create: `app/views/shared/_lure_card.html.erb`, `_catch_card.html.erb`, `_combobox.html.erb`, `_provenance.html.erb`, `_pagination.html.erb`, `_badge.html.erb`, `_promoted_badge.html.erb`, `_country_flag.html.erb`
- Create: `app/helpers/flags_helper.rb` (circular flag SVG/emoji per country code), `app/helpers/pagination_helper.rb`
- Test: `test/helpers/flags_helper_test.rb`

- [ ] **Step 1:** Port `LureCard` markup exactly (image/placeholder lure-hook SVG, proof badge "{n} catches" or dashed "No proof yet", brand/model, type/depth/action chips, species pills or "Be the first…"). Accepts a `lure` local.
- [ ] **Step 2:** Port `CatchCard` (photo or fish placeholder, multi-photo count badge, contributor initials, species name, "on {lure}", condition chips, contributor flag + name + date, upvotes). Accepts `catch`.
- [ ] **Step 3:** Port `Provenance` ("History & ownership", primary avatar, owner verified badge, creator line, edit timeline). Accepts `subject`.
- [ ] **Step 4:** `_combobox` partial rendering a Stimulus combobox bound to a form field + options. `_pagination` (page window). `flags_helper` circular flag.
- [ ] **Step 5:** Helper test for flags. Commit.

---

## Task 11: Lures — home/index (default, sorted by catch count desc), filters, detail (rich + sparse), add-a-lure

**Files:**
- Create: `app/controllers/lures_controller.rb`
- Views: `app/views/lures/{index,show,new}.html.erb`, partials for variants table, buy links, action-video link
- Test: `test/controllers/lures_controller_test.rb`, request specs

- [ ] **Step 1:** Tests: `index` is root, lists lures ordered by `catches_count` desc, paginates; type-filter chips filter; sparse "no matches" state. `show` renders rich lure (variants, proof grid of catch cards, species proven links, buy links with promoted pinned, provenance, action-video link, "Add a catch" for signed-in / "Sign in to contribute" for guest) and the unproven lure shows "Be the first to prove this lure works". `new` requires login.
- [ ] **Step 2:** Controller actions + strong params; index reads filters from query (type/species/brand/season/water_body/clarity/wind/action/depth/saltwater) via a `LureFilter` query (create `app/queries/lure_filter.rb` with its own test).
- [ ] **Step 3:** Views porting prototype layout (two-column detail with sidebar provenance/quick-facts; responsive). Add active-filter pills with remove.
- [ ] **Step 4:** Run tests green. Commit.

---

## Task 12: Species — index, detail with tabs (Lures/Catches/Leaderboard/History), sparse state, add-a-species

**Files:**
- Create: `app/controllers/species_controller.rb`
- Views: `app/views/species/{index,show,new}.html.erb`
- Test: `test/controllers/species_controller_test.rb`

- [ ] **Step 1:** Tests: `index` paginates species cards (translated common names, sci name, lure/catch counts); `show` has 4 tabs — Lures (proven lures grid), Catches (catch cards), Leaderboard (uses `LeaderboardQuery` scoped to species, metric toggle), History (provenance). Unproven species shows sparse "no proven lures yet → invite contribution".
- [ ] **Step 2:** Controller + views (tabs via Stimulus `tabs`). Translated names through taxonomy helper.
- [ ] **Step 3:** Green. Commit.

---

## Task 13: Brands — index, detail with tabs (Lures/History), claim CTA; add-a-brand

**Files:**
- Create: `app/controllers/brands_controller.rb`; views `{index,show,new}`
- Test: `test/controllers/brands_controller_test.rb`

- [ ] **Step 1:** Tests: `index` paginates brand cards (logo/initials, country flag, founded, lure count, claimed badge); `show` tabs Lures + History; unclaimed brand shows "Claim this brand" (signed-in), claimed shows verified owner. `new` requires login.
- [ ] **Step 2:** Controller + views. Commit when green.

---

## Task 14: Shops — index (promoted pinned + labeled), expandable history, add-a-shop; buy-link rendering

**Files:**
- Create: `app/controllers/shops_controller.rb`; views `{index,new}` + `_shop_row`
- Test: `test/controllers/shops_controller_test.rb`

- [ ] **Step 1:** Tests: promoted shops render first in a labeled "Promoted" section with the amber promoted badge; regular shops paginate (3/page); each shows owner (claimed) or "Added by {creator}", expandable history; "Claim a shop" CTA.
- [ ] **Step 2:** Controller + views. Commit when green.

---

## Task 15: Catches — index, detail (gallery, conditions, contributor, comments, upvote, report), add-a-catch flow

**Files:**
- Create: `app/controllers/catches_controller.rb`, `comments_controller.rb`, `upvotes_controller.rb`
- Views: `catches/{index,show,new}`, comment partial
- Test: `test/controllers/catches_controller_test.rb`, request specs incl. create

- [ ] **Step 1:** Tests: `index` paginates catch cards (8/page); `show` renders gallery (multi-photo carousel), species+lure links, contributor (flag/role badge), localized date, location, units-formatted length/weight, conditions grid, comments, upvote toggle (signed-in), report link. `new` requires login; `create` with photos + conditions + variant + species + length/weight persists, creates a `ModerationItem(kind: :catch)` and a `Revision`, redirects to a success state. Comment create requires login. Upvote toggles count.
- [ ] **Step 2:** Implement controllers (combobox-driven lure→variant→species selects, multi-image upload), Turbo Stream for upvote + comment.
- [ ] **Step 3:** Green (incl. integration test for the full submit happy path). Commit.

---

## Task 16: Search + filter results

**Files:**
- Create: `app/controllers/search_controller.rb`; view `search/index`
- Test: `test/controllers/search_controller_test.rb`

- [ ] **Step 1:** Tests: query `q` searches lures (model/brand), species (translated common name), brands; results grouped in sections with counts; empty state; the header filter dropdown (type/water/action/depth/species/brand/season/clarity/wind/saltwater) applies and lands on filtered lures with active pills.
- [ ] **Step 2:** Controller reuses `LureFilter`; view sections. Commit when green.

---

## Task 17: Leaderboard page (species filter + metric toggle)

**Files:**
- Create: `app/controllers/leaderboard_controller.rb`; view `leaderboard/index`
- Test: `test/controllers/leaderboard_controller_test.rb`

- [ ] **Step 1:** Tests: default "All species" + metric Catches; species chips re-rank; metric toggle (Catches/Upvotes/Fish length) reorders and highlights the active column; medal ranks for top 3; current-user row highlighted ("YOU"); empty state.
- [ ] **Step 2:** Controller uses `LeaderboardQuery`; view with chips + toggle + table. Commit when green.

---

## Task 18: Auth UI — sign-in/up modal, registration (country + language + units), my catches, settings

**Files:**
- Modify: generated `SessionsController`; create `RegistrationsController`, `SettingsController`, `DashboardController`
- Views: sign-in modal partial, `registrations/new`, `settings/edit`, `dashboard/catches`
- Test: request specs

- [ ] **Step 1:** Tests: sign-in modal posts to session; registration captures name/email/password + country (flag grid) + language (radio) + units, creates member, signs in; gated-action redirect remembers intent and returns post-login; `settings#update` changes country/language/units (comboboxes) and persists; `dashboard#catches` lists current user's catches + total upvotes; sign-out works.
- [ ] **Step 2:** Implement. Wire avatar menu + "Sign in" button + language switcher to set guest locale (cookie) and signed-in users to their `locale`. Commit when green.

---

## Task 19: Contribution flows — suggest-edit (lure/brand/shop), claim (3-step DNS TXT), report modal

**Files:**
- Create: `app/controllers/revisions_controller.rb`, `claims_controller.rb`, `reports_controller.rb`
- Views: `revisions/new`, `claims/new` (stepper), report modal partial
- Test: request specs

- [ ] **Step 1:** Tests: suggest-edit (signed-in) creates a `Revision` + `ModerationItem(kind: :edit)`, shows "your suggestion will be reviewed"; claim flow renders 3 steps, shows the TXT record `lurepedia-verify=lp_...`, `verify` simulates success → claim verified + `ModerationItem(kind: :claim)`; report modal POST creates `Report` + `ModerationItem(kind: :report)` and is gated.
- [ ] **Step 2:** Implement controllers + views + `claim_verify` Stimulus. Commit when green.

---

## Task 20: Moderation queue + admin console

**Files:**
- Create: `app/controllers/moderation_controller.rb`, `admin_controller.rb` (or `Admin::*`)
- Views: `moderation/index` (+ item detail), `admin/{overview,people,activity}`
- Test: request specs

- [ ] **Step 1:** Tests: moderation index (moderator+) lists `ModerationItem.pending` with type-coded badges + filter chips with counts; approve/reject updates status + counts (Turbo Stream) with Undo; claims/locked items show "Needs admin" for moderators; item detail viewable. Admin overview shows stats; People tab lists users with role combobox (admin changes role); Activity log lists revisions/actions. Member access denied.
- [ ] **Step 2:** Implement with policy gating + Turbo Streams. Commit when green.

---

## Task 21: Seeds (users, full catalog, images via Active Storage, translations sanity)

**Files:**
- Create: `db/seeds.rb` (+ `db/seeds/` helpers), copy images into `db/seeds/lure_images/` and `db/seeds/catch_images/`
- Test: `test/integration/seeds_smoke_test.rb` (optional: load a subset)

- [ ] **Step 1:** Copy the 12 files from `/Users/deyan.dobrinov/dev/personal/allthelures/db/seeds/lure_images/` into repo `db/seeds/lure_images/`, and the 7 `~/Desktop/PNG image*.png` into `db/seeds/catch_images/` (renamed `catch1..7.png`).
- [ ] **Step 2:** `seeds.rb`: create users — `admin@example.com` (admin), `moderator@example.com` (moderator), `user1@example.com`..`user5@example.com` (members), all password `"1"`, with realistic names/countries/locales. Idempotent (`find_or_create_by`).
- [ ] **Step 3:** Create lure types, brands (Megabass/Rapala/Strike King/Z-Man/Booyah/Berkley…), species (incl. one unproven e.g. rainbow trout), lures (incl. one unproven), variants (attach the 12 lure images round-robin), shops (incl. 2 promoted) + buy links.
- [ ] **Step 4:** Create catches across members + species/variants with conditions/notes/length/weight, attach 1–3 catch photos each (from the 7), comments, upvotes, revisions; seed a few pending moderation items (a catch, an edit, a report, a claim) and one verified + one pending claim. Recompute counter caches.
- [ ] **Step 5:** Run `bin/rails db:seed`; verify counts via console. Commit (do NOT commit large images if they bloat — but these are needed for seeds, so commit them under `db/seeds/`).

---

## Task 22: SEO finishing — sitemap, JSON-LD, meta per page, robots

**Files:**
- Create: `app/controllers/sitemaps_controller.rb` + route `/sitemap.xml`, view `sitemaps/index.xml.builder`
- Modify: per-controller `page_title`/`meta_description`/JSON-LD; `public/robots.txt`
- Test: `test/integration/seo_test.rb`

- [ ] **Step 1:** Tests: `/sitemap.xml` lists every public URL × every locale with `xhtml:link` alternates; lure/species pages emit localized `<title>`, meta description, canonical, hreflang, and Product/BreadcrumbList JSON-LD; `robots.txt` references the sitemap.
- [ ] **Step 2:** Implement. Commit when green.

---

## Task 23: Full-suite verification + responsive/a11y pass

- [ ] **Step 1:** Run `bin/rails test` and `bin/rails test:system` — all green. Fix any failures (use systematic-debugging skill if needed).
- [ ] **Step 2:** Run `bin/rubocop` (omakase) and `bin/brakeman`; address findings.
- [ ] **Step 3:** Manual responsive smoke at 1200/780/520px on home, lure detail, species detail, catch detail, moderation. Verify focus states + keyboard nav on combobox/modal/menus.
- [ ] **Step 4:** Final commit.

---

## Self-review notes (coverage check)
- Every spec screen → a task (Lures 11, Species 12, Brands 13, Shops 14, Catches 15, Search 16, Leaderboard 17, Auth/settings/my-catches 18, suggest/claim/report 19, moderation/admin 20).
- i18n/SEO → Tasks 2, 4, 22. Units → 7. Taxonomy → 4. Roles/gating → 1, 8. Provenance → 6, 10. Seeds + images → 21. Interactivity → 9. Tokens/chrome → 3.
- No placeholders left as work items; each task lists exact files + test focus. Larger-than-2-min tasks are intentional given the one-pass scope; within each, follow TDD step order (test → red → implement → green → commit).
