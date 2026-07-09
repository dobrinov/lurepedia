# Hook type attribute + filter

## Problem

Anglers filter by what a lure is **rigged with** — treble hooks, single hooks,
or none — because it drives fish-holding, hookup rate, catch-and-release
friendliness, and where it's legal (many fisheries are single-hook/barbless
only). Direct feedback: куки — без / единични / тройни (hooks — none / single /
treble). The catalog records none of it.

## Placement — on `Build` (not `Lure`)

Material went on `Lure` because a model is one material in every size. Hooks are
different: hook rigging is a **physical spec of a specific build**, and it does
vary within a model — a saltwater build ships heavier singles, a downsized build
carries fewer/smaller trebles, and manufacturers sell single-hook versions of a
size as their own SKU. So `hook_type` joins the other per-build physical
specs (`length_mm`, `weight_g`, depth, `action`, `water`) on `builds`.

Consequences that make this the right home:

- It renders naturally as **another column in the per-build variations table**,
  right next to buoyancy/water — no new display surface invented.
- The filter reuses the established **"a lure matches if any of its builds
  matches"** pattern (`apply_action`/`apply_depth`), so a search for single-hook
  lures surfaces any lure offering a single-hook build.

## Data model

```ruby
class AddHookTypeToBuilds < ActiveRecord::Migration[8.1]
  def change
    add_column :builds, :hook_type, :integer   # nullable — nil = unknown
  end
end
```

```ruby
# Build
enum :hook_type, { none: 0, single: 1, treble: 2 }, prefix: :hook
```

- **Nullable, nil = unknown, no backfill** — like the other nullable build specs.
  Most imported builds have no hook data and must stay unasserted.
- `none` (explicitly hookless) is a real, distinct value from `nil` (unknown).
  The two must read differently in the UI (see Display): `none` → "No hooks",
  `nil` → the "—" unknown marker used by the other spec columns.

## Filter

A small static enum → inline-combobox filter, exactly like buoyancy
(`lure_action`).

- `SearchFiltersHelper::STATIC_FILTERS` — add `:hook`.
- `static_filter_options(:hook)` → `Build.hook_types.keys.map { |k| [ hook_type_name(k), k ] }`.
- `filter_label(:hook)` → `t("lure.hooks")`; `filter_placeholder(:hook)` → `t("search.any_hooks")`.
- `LureFilter::ATTRS` — add `:hook` (param name `hook`, column `hook_type`, to
  keep the URL short, mirroring `lure_action` → `action`).
- `apply_catalog` — `scope = scope.where(id: Build.where(hook_type: @p[:hook]).select(:lure_id)) if hook?`,
  where `hook?` guards against unknown values (`Build.hook_types.key?`).
- `active_pills` — a `:hook` pill labelled `I18n.t("hook.#{@p[:hook]}")`.

## Display

- **Variations table** (`lures/show`): add a **Hooks** column (`t("lure.hooks")`
  header) between Buoyancy/Water and the add-catch button. Cell renders
  `hook_type_name(b.hook_type)` when set, else `t("common.none")` ("—") — the
  same "unknown → dash" treatment as size/weight/depth.
- `hook_type_name(key)` helper alongside `material_name` (translates
  `hook.<key>`), used by the table cell, the filter options, and the pill.
- The `none` value's label is "No hooks" (not "—"), so an explicitly-hookless
  build is distinguishable from an unknown one.

## Edit

Rides `commit_edit` — `BuildsController#update`/`create` already funnel
`build_params` through it.

- `build_params` — permit `:hook_type`; normalize `""` → `nil` (the blank
  "unknown" choice can't be assigned to the enum), the same guard used for
  `lure.material`.
- `builds/_form` — a `hook_type` `<select>` after Water, with `include_blank`
  for "unknown" plus the none/single/treble options.

## Localization (all 19 locales)

- `lure.hooks` — column header / filter label ("Hooks").
- `search.any_hooks` — filter placeholder ("Any hooks").
- top-level `hook:` map — `none` ("No hooks"), `single` ("Single"),
  `treble` ("Treble").

`no` locale keys stay quoted.

## Tests

- `LureFilter`: `hook: "single"` returns only lures with a single-hook build;
  unknown values ignored (parity with `lure_action`); `hook` pill present;
  the "any build matches" semantics (a lure with one treble and one single
  build matches both).
- Build edit: setting `hook_type` persists; blank clears to `nil`.

## Touch list

- Migration (`add_column :builds, :hook_type, :integer`)
- `app/models/build.rb` — enum
- `app/helpers/taxonomy_helper.rb` — `hook_type_name`
- `app/helpers/search_filters_helper.rb` — `STATIC_FILTERS`, options/label/placeholder
- `app/queries/lure_filter.rb` — `ATTRS`, `apply_catalog`, `hook?`, pill
- `app/controllers/builds_controller.rb` — permit + blank→nil
- `app/views/builds/_form.html.erb` — hook_type select
- `app/views/lures/show.html.erb` — Hooks column in the variations table
- 19 locale files — `lure.hooks`, `search.any_hooks`, `hook.*` (3)
- `db/seeds.rb` — a hook_type on a seeded build
- Tests above
