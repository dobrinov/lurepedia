# Design system page (`/design-system`)

## Problem

UI elements (tokens, component classes, shared partials) live across
`application.css` and `app/views/shared`, but there is no single place to see
them together. A living styleguide makes inconsistencies visible and gives a
reference for building new screens.

## Approach

A public, tabbed gallery at `/design-system` that renders the **real** components
from in-memory sample data — never static copies, so it can't drift from
production.

### Route & controller
- `get "design-system", to: "design_system#index", as: :design_system`, inside the
  locale scope. Public (no auth, all environments).
- `DesignSystemController#index` exposes in-memory sample objects. No DB writes.

### Sample data
`app/models/design_system/sample_data.rb` — a PORO that builds the objects the
data-coupled partials need, keeping the controller thin:
- Leaderboard rows: plain `Struct`s (`user`, `catches`, `upvotes`, `best_length_cm`).
- Lure / catch / provenance: `Lure.new` / `Catch.new` with `brand`, `lure_type`,
  `species`, `user` assigned in memory. A few methods are stubbed on the sample
  instances so the production partials render unchanged:
  - `to_param` → a slug, so `lure_path` / `catch_path` generate URLs.
  - `proven_species` → returns something responding to `.limit(n)`.
  - `revisions` → returns chronological/newest_first-capable sample revisions.
- Two lure cards are shown: a proven one (with species pills) and an unproven one.

### Layout — tabbed (reuses the existing `tabs` Stimulus controller)
1. **Foundations** — color swatches for every token (neutrals, accent, success,
   amber, danger, medals), typography scale (h1–h4, body, muted, small), radii,
   shadows, focus ring.
2. **Buttons & Forms** — `btn` / `btn-primary` / `btn-sm` / disabled; text input,
   search field, client-side combobox, async combobox, toggle, checkbox.
3. **Indicators** — chips, tags, pills, proof / no-proof badges, role badges,
   medal ranks, flash (notice + alert), empty state.
4. **Navigation** — tabs, pagination, avatar dropdown menu, language switcher pill.
5. **Components** — base card, lure card (proven + unproven), catch card,
   leaderboard table, provenance panel, fish / lure glyphs.

Each example sits in a labeled "spec row": the rendered element plus a caption
naming its CSS class (e.g. `.btn-primary`), so the page doubles as a usage
reference.

### Files
- `app/controllers/design_system_controller.rb`
- `app/models/design_system/sample_data.rb`
- `app/views/design_system/index.html.erb` — tab scaffold rendering one partial per
  tab: `_foundations`, `_buttons_forms`, `_indicators`, `_navigation`, `_components`.
- A small `Design system` section in `application.css` for gallery layout only
  (`.ds-grid`, `.ds-swatch`, `.ds-row`, `.ds-label`).

### Conventions
- **i18n:** page chrome (tab/section labels) stays plain English — internal
  styleguide; not added to the 10 locale files.
- **Nav link:** unlinked (reachable at `/design-system`). Optional footer link if
  wanted later.

### Testing
- Integration test: `GET /design-system` → 200, renders without error, and a
  swatch, `.btn-primary`, and a rendered `.lure-card` are present. This guards the
  in-memory partial rendering, which is the main fragility.
