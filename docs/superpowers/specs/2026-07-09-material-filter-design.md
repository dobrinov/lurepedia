# Material attribute + filter

## Problem

Anglers filter lures by what they're **made of** — plastic, wood, metal, etc.
It changes action, durability, price, and feel, and it's a common first-pass
narrowing ("a wooden minnow", "a metal jig"). The catalog records none of it,
so it can't be shown or searched. This is direct angler feedback (материал:
пластмаса / композит / дърво / метал / силикон / друго).

## Placement — on `Lure`

Material is a property of the **model**, not of a color or a size: a Vision 110
is plastic in every color and every build. So it's a single enum column on
`lures`, unlike glow/uv (per-color) or length/weight (per-build). This also
makes it the cheapest kind of filter — a direct `where` on the lures table with
no join.

## Data model

```ruby
class AddMaterialToLures < ActiveRecord::Migration[8.1]
  def change
    add_column :lures, :material, :integer   # nullable — nil = unknown
  end
end
```

```ruby
# Lure
enum :material, { plastic: 0, composite: 1, wood: 2, metal: 3, silicone: 4, other: 5 }, prefix: :material
```

- **Nullable, no default, no backfill.** Like the nullable build specs
  (`length_mm` etc.), `nil` means "unknown", not "plastic". The overwhelming
  majority of the imported catalog has no material recorded and must stay
  unasserted — we never guess. Values only ever *add* precision when a
  contributor or a future import sets one. This matches the open-world stance
  used everywhere else in the catalog.
- Enum values are the six from the feedback. `other` is the catch-all so the
  set stays closed and translatable; genuinely unknown stays `nil`.

## Filter

`material` is a small static enum → it joins the existing inline-combobox
filters, exactly like `type`.

- `SearchFiltersHelper::STATIC_FILTERS` — add `:material`.
- `static_filter_options(:material)` → `Lure.materials.keys.map { |k| [ material_name(k), k ] }`.
- `filter_label(:material)` → `t("lure.material")`; `filter_placeholder(:material)`
  → `t("search.any_material")`.
- `LureFilter::ATTRS` — add `:material`.
- `apply_catalog` — `scope = scope.where(material: @p[:material]) if present?(:material) && Lure.materials.key?(@p[:material])`
  (guarded against unknown values, like `lure_action`).
- `active_pills` — `pills << [ :material, material_name(@p[:material]) ] if present?(:material) && Lure.materials.key?(@p[:material])`.

## Display

- **Show page** (`lures/show`): add a `.tag` to the existing chips row (next to
  type / action / water) only when material is present:
  `<% if @lure.material %><span class="tag"><%= material_name(@lure.material) %></span><% end %>`.
- A `material_name(key)` helper alongside `lure_type_name` / `water_name`
  (translates `material.<key>`), used by both the tag and the filter options.

## Edit

Rides the existing `commit_edit` path — `LuresController#update` already funnels
`lure_params` through it, so moderation/ownership rules apply for free.

- `lure_params` — permit `:material`.
- `lures/_form` — a material `<select>` (inline combobox like `type`), with a
  blank "unknown" option so a lure can be set back to unrecorded.

## Localization (all 19 locales)

New keys:
- `lure.material` — field/column label ("Material").
- `search.any_material` — filter placeholder ("Any material").
- `material.plastic` / `.composite` / `.wood` / `.metal` / `.silicone` / `.other`
  — the six value labels.

Filter pill and combobox reuse these. `no` locale keys stay quoted.

## Design system

`DesignSystem::SampleData` builds `Lure` with `.new` — add `material: :plastic`
(or similar) to a sample so the styleguide's lure chips show the new tag, if a
partial that renders it is exercised there.

## Tests

- `LureFilter`: `material: "wood"` returns only wooden lures; unknown values are
  ignored (parity with `lure_action`); material appears in `active_pills`.
- Lure edit: an admin sets `material` and it persists; a member's change routes
  through moderation (covered by the existing `commit_edit` edit tests — add a
  material assertion rather than a new flow).

## Touch list

- Migration (`add_column :lures, :material, :integer`)
- `app/models/lure.rb` — enum
- `app/helpers/…` — `material_name` helper
- `app/helpers/search_filters_helper.rb` — `STATIC_FILTERS`, options/label/placeholder cases
- `app/queries/lure_filter.rb` — `ATTRS`, `apply_catalog`, `active_pills`
- `app/controllers/lures_controller.rb` — permit `:material`
- `app/views/lures/_form.html.erb` — material select
- `app/views/lures/show.html.erb` — material tag in chips row
- 19 locale files — `lure.material`, `search.any_material`, `material.*` (6)
- `DesignSystem::SampleData` — sample material (if needed)
- Tests above
