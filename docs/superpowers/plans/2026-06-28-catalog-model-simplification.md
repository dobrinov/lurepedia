# Catalog Model Simplification — Plan

Date: 2026-06-28
Branch base: `edit-history-diffs` (after commit `8fcf1fb`, the data-integrity fixes)

## Goal

Simplify the Brand → Lure → (colors × sizes) catalog into a flexible, hard-to-corrupt
foundation, without losing the useful orthogonality of describing colors and sizes
independently. Four self-contained changes, each its own commit with green tests.

### Decisions (settled)

- **Keep two independent axes** of a `Lure`: `variants` (colors/finishes) and
  `builds` (sizes / action / depth).
- **Drop the `variant_builds` availability matrix.** In a community wiki, "which
  color comes in which size" is rarely a hard constraint and is not worth a join
  table, a dual-reconciling picker, and an availability JSON contract.
- **`Catch`: variant required, build optional**, with a validation that the build
  (when present) belongs to the same lure as the variant — closing the current
  two-FK integrity gap.
- **Stop shadowing the `default_variant` association**; keep the explicit FK.
- **Dedup** the `{ fresh, salt, both }` water enum into one concern.

---

## Part D — water enum concern  *(do first; trivial, no schema)*

The enum `{ fresh: 0, salt: 1, both: 2 }` is declared identically in `Build#water`,
`Species#water`, and `LureType#water_default`.

- New `app/models/concerns/water_classified.rb` exposing a class macro:
  ```ruby
  module WaterClassified
    extend ActiveSupport::Concern
    class_methods do
      def water_enum(column = :water)
        enum column, { fresh: 0, salt: 1, both: 2 }, prefix: :water
      end
    end
  end
  ```
- `Build`/`Species`: `include WaterClassified` + `water_enum`.
- `LureType`: `include WaterClassified` + `water_enum(:water_default)`.
- No migration, no behaviour change. Existing tests cover it.

## Part C — de-shadow `default_variant`  *(no schema)*

`Lure#default_variant` currently overrides the association getter with
`super || variants.order(:id).first`, which breaks eager-loading and lets
`default_variant_id` go stale.

- **Remove** the `def default_variant` override in `Lure`. Keep the
  `belongs_to :default_variant` association and the `default_variant_id` FK (the
  explicit pick).
- **Add** `Lure#primary_variant` → `default_variant || variants.order(:id).first`
  (the resolved "shown" color; does not shadow the association).
- `Variant#default?` → `lure.primary_variant&.id == id`.
- Update callers to use `primary_variant` for the resolved color:
  - `lures_controller#show` (`@default_variant = @lure.primary_variant`)
  - `lures#variations` JSON `default:` flag
  - `app/views/shared/_lure_card.html.erb`
  - `app/models/design_system/sample_data.rb` (keep the styleguide stub in sync)
- Tests: `two_axis_variant_test` default-variant cases adjust to the
  `primary_variant` resolution (explicit choice still wins; first-added is the
  fallback).

## Part A — Catch integrity + optional build  *(schema: nullable + validation)*

- **Migration**: `change_column_null :catches, :build_id, true`.
- `Catch`:
  - `belongs_to :build, counter_cache: :catches_count, optional: true`
  - `validate :build_belongs_to_same_lure` →
    when `build` present, `build.lure_id == variant.lure_id`, else add error on
    `:build`. (`variant` stays required, so `variant.lure_id` is always available.)
  - Lure counter bump via `variant.lure_id` is unchanged.
- Catch form (`catches/new.html.erb`): build select becomes optional (no longer a
  required field); copy/label tweak.
- Tests (`two_axis_variant_test`):
  - replace "a catch requires a build" with "a catch may omit a build".
  - add "a catch rejects a build from a different lure".

## Part B — drop the `variant_builds` matrix  *(schema: drop table)*

Do **after** Part A (the picker/JSON depend on both being settled).

- **Migration**: `drop_table :variant_builds`.
- **Models**: delete `app/models/variant_build.rb`; remove `has_many
  :variant_builds` / `:builds` from `Variant` and `:variant_builds` / `:variants`
  from `Build`. (`Variant` and `Build` remain independent children of `Lure`.)
  Delete the `variant_builds` fixture if present.
- **`lures#variations` JSON**: colors no longer carry `build_ids`; `builds` is a
  flat list for the lure. Remove the `@availability` hash from `lures#show` and
  the `VariantBuild.where(...)` lookups.
- **`catch_picker_controller.js`**: colors and builds load independently after a
  lure is chosen. `populateBuilds` shows **all** of the lure's builds (drop the
  `color.build_ids` allow-set and the per-color refiltering in `colorChanged`).
- **`variants/_form.html.erb`** + `variants_controller#variant_params`: remove the
  `build_ids` availability checkboxes and the param.
- **`lures/show.html.erb` / `lures/edit.html.erb`**: remove any availability-matrix
  rendering; show colors and builds as two plain lists.
- Tests (`variations_flow_test`): drop the `VariantBuild` setup and the
  `build_ids` assertions; assert the builds list is returned flat. Remove the
  matrix case from `two_axis_variant_test`.

---

## Sequencing

1. **Part D** (concern) — trivial, isolated.
2. **Part C** (default_variant) — isolated.
3. **Part A** (catch integrity + optional build) — schema + validation.
4. **Part B** (drop matrix) — schema + JSON/JS/views in lockstep.

Each part: migrate (where applicable), update `db/seeds.rb` if it references the
dropped structures (the seed creates `VariantBuild` rows — remove in Part B), keep
`design_system/SampleData` in sync, run the full suite, commit.

## Risks / notes

- Migrations are destructive (`drop_table`, nullability change). Irreversible once
  prod data exists — fine pre-release; flag before running against any real data.
- The `/variations` JSON is a contract with `catch_picker_controller.js`; they must
  change together (Part B).
- `best_for` / `uv_glow` on `Variant` are out of scope (legitimate color attributes).
- Lure body size stays in **mm** by convention — do not touch `builds.length_mm`
  (see prior decision; it is intentionally exempt from unit conversion).
- Pre-existing `catalog_screens_test` hero failures (lines 21/37/195) are unrelated
  and predate this work; don't treat them as regressions.
