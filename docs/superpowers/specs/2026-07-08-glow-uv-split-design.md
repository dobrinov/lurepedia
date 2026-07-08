# Split `uv_glow` into `glow` + `uv`

## Problem

`Variant` carries a single boolean `uv_glow` that conflates two physically
distinct finish properties an angler chooses between:

- **Glow** — phosphorescent pigment that stores light and *emits* it in the
  dark (a green/blue afterglow at depth or at night). Relevant for deep
  jigging, night fishing, murky water.
- **UV** — a finish that *reflects* ultraviolet, so it looks ordinary in
  visible light but "pops" under the UV that penetrates deeper/colder water.
  Relevant for bright-but-deep and clear-water conditions.

A lure can be one, both, or neither, and anglers filter on them for different
reasons. Today the catalog can't express "glows in the dark but is not
UV-reactive" (or the reverse), and the property isn't even searchable —
`uv_glow` appears nowhere in `LureFilter::ATTRS`. This came up as direct
angler feedback: *"glow and UV are two different things — glow is phosphor that
lights up in the dark; UV colours look different under the ultraviolet
spectrum."*

## Scope

Two changes that ship together:

1. **Model fix** — replace the one boolean with two (`glow`, `uv`) and update
   every read/write site.
2. **New filters** — expose both as search toggles (this data has never been
   filterable; adding the columns without the filter would waste the feedback).

Out of scope: any of the other requested filters (hooks, material, technique,
price). Those are separate specs.

## Data model

`glow` and `uv` are per-**colour** properties (a phosphor or UV pigment is a
finish trait), so they stay on `Variant`, exactly where `uv_glow` lived.

```ruby
class SplitVariantUvGlow < ActiveRecord::Migration[8.1]
  def up
    add_column :variants, :glow, :boolean, default: false, null: false
    add_column :variants, :uv, :boolean, default: false, null: false
    # Historic uv_glow was surfaced in the UI as a "UV" badge, so it means UV,
    # not phosphorescence. Preserve that meaning; leave glow at its default.
    execute "UPDATE variants SET uv = uv_glow"
    remove_column :variants, :uv_glow
  end

  def down
    add_column :variants, :uv_glow, :boolean, default: false, null: false
    execute "UPDATE variants SET uv_glow = uv"
    remove_column :variants, :glow
    remove_column :variants, :uv
  end
end
```

**Backfill decision:** every existing `uv_glow = true` becomes `uv = true`,
`glow = false`. Rationale — the field was always *rendered* as a "UV" badge
(`lures/show`, `lures/edit`), and the imports that set it (see `db/seeds.rb:200`)
mapped catalog "UV" finishes into it. Nothing in the corpus meant
phosphorescence, so we don't guess `glow`; contributors add it going forward.

No new table, no association changes — same shape as before, one more column.

## Write path

`Variant` edits already funnel through `Editable#commit_edit`; only the
permitted-params list changes.

- `app/controllers/variants_controller.rb:55` — `permit(:name, :best_for,
  :uv_glow, …)` → `permit(:name, :best_for, :glow, :uv, …)`.
- `app/controllers/lures_controller.rb:40` (`/variations` JSON) — the per-colour
  payload ships `uv_glow: v.uv_glow`; replace with `glow: v.glow, uv: v.uv`.
  This is a JSON contract consumed by the catch picker / color tiles, so the
  Stimulus reader for it changes in lockstep (see UI).

## UI

- **Variant form** (`app/views/variants/_form.html.erb:17`) — one checkbox
  becomes two: `f.check_box :glow` + `f.check_box :uv`, each with its own
  label. Add a one-line hint distinguishing them (glow = dark; UV = under UV
  light) so contributors tag correctly.
- **Lure show** (`app/views/lures/show.html.erb`) — today a single `UV` badge
  (lines 45, 76, 111) driven by `dv&.uv_glow` and a `data-uv` tile attribute
  (line 103). Split into a **UV** badge (from `uv`) and a **GLOW** badge (from
  `glow`), and emit both `data-uv` and `data-glow` on the color tile. The
  Stimulus `variant-stage` controller gains a `chipGlow`/`lightboxGlow` target
  mirroring the existing UV plumbing.
- **Lure edit** (`app/views/lures/edit.html.erb:64`) — same badge split in the
  color list.
- **Badge styling** — reuse the `.uv-badge` treatment for a sibling
  `.glow-badge` (distinct colour so the two read apart at a glance).

## Search / filter

New in `LureFilter` (`app/queries/lure_filter.rb`). Both are boolean toggles
matched at the **variant** level — a lure qualifies if *any* of its colours
carries the flag (same "any child matches" pattern as `apply_action`/
`apply_water`, which match on builds):

```ruby
ATTRS = %i[ … glow uv … ].freeze   # add both

def apply_catalog(scope)
  # …
  scope = scope.where(id: Variant.where(glow: true).select(:lure_id)) if truthy?(:glow)
  scope = scope.where(id: Variant.where(uv:   true).select(:lure_id)) if truthy?(:uv)
  scope
end
```

Pills in `active_pills` (label from the same i18n keys as the badges); the
`truthy?` helper already exists. No range/unit handling needed — presence of
the param means "require it".

**Search panel UI:** two checkboxes in the filter form alongside water/action.
Absent = don't constrain (an un-tagged lure isn't excluded), matching the
open-world spirit of the rest of the catalog — we never assert "not glow", only
"has glow".

## Localization

`lure.uv_glow` exists in all 19 locale files (`bg`/`ja`/`de` at line 242, the
rest at 292). Replace that single key with **two** keys — `lure.glow` and
`lure.uv` — in every one of the 19 files (locale parity is mandatory; the `no`
locale's keys stay quoted). Suggested English: `glow: "Glow"`,
`uv: "UV"`. Existing translations of `uv_glow` were "UV glow"/"UV свечение"
etc.; the new `uv` key inherits the UV half, and `glow` gets a fresh
phosphorescence-sense translation per locale (glow-in-the-dark, not "shine").

Search-panel/pill labels reuse these two keys.

## Tests

- `test/integration/variations_flow_test.rb` (lines 10, 28, 93, 102) uses
  `uv_glow` in fixtures/assertions and checks the `/variations` JSON — update
  to `glow`/`uv` and assert both JSON fields.
- Add `LureFilter` coverage: a `glow=1` search returns only lures with a glow
  colour; `uv=1` likewise; the two are independent (a glow-only lure is not
  returned by `uv=1`).
- Backfill assertion: a pre-existing `uv_glow`-true colour ends up
  `uv: true, glow: false`.

## Touch list (implementation checklist)

- Migration (add `glow`, `uv`; backfill `uv = uv_glow`; drop `uv_glow`)
- `app/models/variant.rb` — no schema code needed, but verify no `uv_glow`
  references linger
- `app/controllers/variants_controller.rb:55` — permitted params
- `app/controllers/lures_controller.rb:40` — `/variations` JSON
- `app/views/variants/_form.html.erb` — two checkboxes + hint
- `app/views/lures/show.html.erb` — UV + GLOW badges, `data-glow`, Stimulus targets
- `app/views/lures/edit.html.erb:64` — badge split
- `app/javascript/controllers/variant_stage_controller.js` — glow targets
- CSS — `.glow-badge`
- `app/queries/lure_filter.rb` — `ATTRS`, `apply_catalog`, `active_pills`
- Search panel partial — two checkboxes
- 19 locale files — replace `uv_glow` with `glow` + `uv`
- `db/seeds.rb:200` — set `glow`/`uv` instead of `uv_glow`
- `DesignSystem::SampleData` — unaffected (`Variant.new` without the flag), but
  add a glow/UV sample colour if the styleguide should show the new badges
- Tests above
```
