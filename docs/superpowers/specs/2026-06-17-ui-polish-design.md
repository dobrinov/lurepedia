# UI Polish: Tabbed Detail Pages & Fixes — Design

Date: 2026-06-17

A batch of UI improvements to the existing Lurepedia frontend. One substantive item — restructuring the lure-details page into path-addressable tabs (and retrofitting the species tabs to match) — plus eight smaller fixes.

All changes follow existing patterns: server-rendered ERB + Hotwire, shared partials, slug-based lookups, `I18n.t` for all strings (maintained locales: en, de, bg, ja).

---

## A. Tab infrastructure — path-segment URLs

Tabs become **separate URLs** via path segments, server-rendered as `<a>` links (shareable, no-JS). This applies to the new lure tabs and the existing species tabs.

### Routing — behavior contract

Each tab is its own path-segment URL. The `:show` action serves both the default (no segment) and the tabbed paths via an optional, **whitelisted** `:tab` segment:

- `/lures/<slug>` → default tab (Caught on it)
- `/lures/<slug>/buy`, `/lures/<slug>/history` → those tabs
- `/lures/<slug>/edit` → still the `edit` action (edit is **not** in the tab whitelist, so the constraint excludes it)
- `lure_path(@lure)` → `/lures/<slug>`; `lure_path(@lure, tab: "buy")` → `/lures/<slug>/buy`

The named `lure_path` helper must emit the optional `/:tab` segment. Note a routing subtlety the plan must handle: `resources :lures` already generates a `lure_path` helper for the `update` (PATCH) route, so the custom GET show route can't blindly re-declare `as: :lure`. The plan resolves this by declaring the GET `lures/:id(/:tab)` route as the canonical `:lure` named route and wiring `update` to share the same path without a duplicate name — e.g.:

```ruby
resources :lures, only: %i[index new create edit]
get   "lures/:id(/:tab)", to: "lures#show", as: :lure, constraints: { tab: /buy|history/ }
patch "lures/:id",        to: "lures#update"
```

Species mirrors this (its collection helper is `species_index_path`; member is `species_path`), with tab whitelist `catches|leaderboard|history` and default tab `lures`.

The controllers read `params[:tab]`, validate it against the known set (falling back to the default), and expose `@tab`. Each tab's data is loaded regardless (the queries are cheap and already run today); only the rendered panel switches. A small shared `_tabs` partial renders the tab bar from a list of `[slug, label, path]` tuples, marking the active one.

### Why server-rendered links over the current JS toggle

The species page currently toggles panels client-side via `tabs_controller.js` with no URL change — tabs aren't linkable. Converting to links gives real URLs, works without JS, and is SEO-visible. The `tabs_controller.js` Stimulus controller is removed (no remaining consumers after this change).

---

## B. Lure details restructure

Single-column layout (the two-column `detail-grid` + `aside` sidebar is removed).

1. **Hero** (unchanged content): variant photo / lure glyph, brand, model `<h1>`, condition chips (type, depth, action, water), proven badge, action row (add-catch / sign-in, edit/suggest-edit, favorite button), optional action-video link.

2. **Variants** — **always visible**, below the hero (not in a tab). The existing `lb-table` gains a leading **thumbnail cell**: each variant renders `variant.photo` (a small `resize_to_fill` variant) when attached, else the shared `lure_glyph`. This makes variant images viewable (the prior page surfaced only one variant photo, in the hero). Empty-state unchanged.

3. **Tabs** (path-addressable, default first):
   - **Caught on it** — `/lures/:slug` (default) — the catches grid (`@catches`, today's "proof" section) with its empty-state.
   - **Where to buy** — `/lures/:slug/buy` — the buy-links list (moved verbatim from the old sidebar tile).
   - **History** — `/lures/:slug/history` — `render "shared/provenance", subject: @lure` (moved from the sidebar).

4. **Removed**: the "Proven for" sidebar tile (`@proven_species` chips) is deleted entirely, along with the sidebar wrapper. `@proven_species` is no longer needed in the controller.

Tab labels use new i18n keys (`lure.tab_caught`, `lure.tab_buy`, `lure.tab_history`).

---

## C. Species page

- Convert the four existing tabs (lures / catches / leaderboard / history) from JS toggles to path-segment links: `/species/:slug` (lures, default), `/species/:slug/catches`, `/species/:slug/leaderboard`, `/species/:slug/history`. Reuse the shared `_tabs` partial.
- **History card full width**: remove the `max-width:420px` wrapper around the history provenance panel (item #8) so it spans the column.
- Existing `species.tab_*` i18n keys are reused.

---

## D. Footer

- The "Видове & more" heading: the `&amp; more` is hardcoded English appended to `t("nav.species")`. Replace the whole heading with a single key `footer.explore`.
- `About` → `footer.about`; `How it works` → `footer.how_it_works`; `Guidelines` → `footer.guidelines`. The two links keep their placeholder `href="#"` (no target pages exist yet) but get translated labels.
- **Remove** the `© <year> Lurepedia` span from `.footer-bottom` (keep the tagline span).
- New `footer.*` keys added to en, de, bg, ja.

---

## E. Catch page — comments & upvote

- **Comment spacing**: the new-comment form sits directly under the comments list with only `margin-top:16px`, which reads cramped. Add clearer separation (increased top spacing / divider) between the last comment and the form.
- **Upvote visual state**: `upvoted_label` currently renders `▲ <count>` regardless of state. When `@catch.upvoted_by?(current_user)`:
  - the `button_to` gets an `is-upvoted` class (a filled/active style in CSS), and
  - a `title`/label cue that another click removes the upvote (new keys `catch.upvote` / `catch.upvoted` / `catch.remove_upvote`).
  - The existing post/delete toggle logic is unchanged.
- A small CSS rule for `.btn.is-upvoted` (active/filled appearance) is added to the stylesheet.

---

## F. Lure index hero

Reduce the hero to **title, subtitle, and a single "Add lure" button** (`new_lure_path`). Remove the "Add a catch", "Species", and "Leaderboard" buttons from the hero. The existing "Browse lures" section-head below keeps the catalog; its duplicate "Add lure" button is removed (the hero now carries it) to avoid two identical CTAs.

---

## Testing

- **Routing/controller**: request specs asserting `/lures/:slug`, `/lures/:slug/buy`, `/lures/:slug/history` each render the right panel (e.g. buy page shows a buy link, history shows a revision); that `/lures/:slug/edit` still hits edit; and an unknown tab segment falls back to the default. Same for species' four tab paths.
- **Views**: the lure page renders the variants table with a thumbnail; the "Proven for" tile is gone; upvote button carries `is-upvoted` when the viewer has upvoted.
- **i18n**: extend the existing `locale_parity_test` coverage — new `footer.*`, `lure.tab_*`, `catch.upvote*` keys must exist in de/bg/ja (the parity test already enforces full key parity for those locales, so it will fail until they're translated).
- Update existing lure/species view tests that assert on the old single-page markup or the JS-tab structure.

## Out of scope

- Building real "How it works" / "Guidelines" pages (labels are translated; links stay `#`).
- Touching the six English-fallback stub locales.
- Variant image lightbox/zoom (thumbnails only; viewing the image is the requirement).
- Any change to the favorites/profiles/bans feature just merged.
