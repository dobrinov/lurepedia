# Technique (application) attribute + multi-select filter

## Problem

Anglers pick lures by the **technique** they're fishing — spinning, jigging,
trolling, drifting. A lure usually suits several. Direct feedback: приложение —
спининг / джигинг / тролинг / дрифтинг / други. The catalog records none of it,
and unlike every filter so far this is **multi-valued** — a lure has a *set* of
techniques, not one.

## Shape — reference table + join (the `_ids` pattern)

Techniques are a fixed, translatable vocabulary attached many-to-many to lures.
Model it exactly like `lure_type` (a keyed reference table) crossed with
`variant_builds` (a join whose membership rides `commit_edit`):

- **`techniques`** — a reference table with a unique `key` (like `lure_types`).
  Fixed rows: `spinning`, `jigging`, `trolling`, `drifting`, `other`.
- **`lure_techniques`** — join (`lure_id`, `technique_id`, unique pair).
- `Lure has_many :lure_techniques, dependent: :destroy; has_many :techniques,
  through: :lure_techniques`.

Why a reference table and not an enum on the join row: it gives a real
`technique_ids=` collection setter, which is what lets a technique edit
**round-trip through `commit_edit` and moderation with zero new code** —
`build_changeset` already special-cases `*_ids` keys (the same path variant
availability uses). An enum-on-join would need bespoke changeset/approval logic.

## Seeding the reference rows — in the migration, not seeds.rb

`db/seeds.rb` is a no-op in production (`Rails.env.local?`), and there's no
import that would create techniques the way brand imports create `lure_types`.
So the five fixed rows are inserted **by the migration** (idempotent), which
runs on every deploy via `db:prepare`. This guarantees dev and prod both have
them. The test DB loads `schema.rb` (structure only, no rows), so tests create
the technique rows they need in setup.

## Data model

```ruby
class CreateTechniques < ActiveRecord::Migration[8.1]
  def up
    create_table :techniques do |t|
      t.string :key, null: false
      t.timestamps
    end
    add_index :techniques, :key, unique: true

    create_table :lure_techniques do |t|
      t.references :lure, null: false, foreign_key: true
      t.references :technique, null: false, foreign_key: true
      t.timestamps
    end
    add_index :lure_techniques, [ :lure_id, :technique_id ], unique: true

    %w[spinning jigging trolling drifting other].each do |k|
      execute "INSERT INTO techniques (key, created_at, updated_at) VALUES ('#{k}', datetime('now'), datetime('now'))"
    end
  end

  def down
    drop_table :lure_techniques
    drop_table :techniques
  end
end
```

`Technique` model mirrors `LureType`: `has_many :lure_techniques`,
`has_many :lures, through:`, `validates :key`, `#name` via `t("technique.#{key}")`,
`to_param = key`. `LureTechnique`: `belongs_to :lure`, `belongs_to :technique`.

## Filter — multi-select, "matches any"

- URL param `technique[]` carries **keys** (`?technique[]=trolling&technique[]=jigging`),
  stable and readable — same key-based convention as the `type` filter (while
  the edit form uses ids, like `lure_type_id`).
- `LureFilter`: a lure matches if it has **any** selected technique (OR — the
  useful facet semantics). Guard to recognised keys:
  ```ruby
  def technique_keys
    Array(@p[:technique]).map(&:to_s) & Technique.pluck(:key)
  end
  # apply_catalog:
  scope = scope.where(id: LureTechnique.joins(:technique)
    .where(techniques: { key: technique_keys }).select(:lure_id)) if technique_keys.any?
  ```
- `ATTRS` — add `:technique`.
- **Pill**: one combined pill (label = selected technique names joined), clearing
  the whole `technique` param — `pill_params(:technique) => ["technique"]`, which
  the existing `except(*pill_params)` removal handles. (Per-value removal would
  need a bespoke URL builder; a combined pill matches the range-pill precedent.)

## Search panel UI

A dedicated cell (techniques don't fit the single-select `STATIC_FILTERS` grid):
a `.stack` of `.toggle` switches, one per technique, named `technique[]` by key —
reusing the glow/UV toggle styling.

## Edit UI + persistence

- `lures/_form`: a `.stack` of `.toggle` switches named `lure[technique_ids][]`
  by **id**, plus a `hidden_field_tag "lure[technique_ids][]", ""` so unchecking
  all submits an empty set (clears) — the same shape as the variant `build_ids`
  availability form.
- `lure_params`: permit `technique_ids: []`; strip the blank sentinel
  (`reject(&:blank?)`), like variant `build_ids`.
- Persistence is automatic: `technique_ids` flows through `commit_edit` →
  `build_changeset` (`_ids` diff) → `record.update` (collection setter) →
  moderation round-trip for members.

## Display

- `lures/show` chips row: one `.tag` per technique (after the material tag),
  when present.
- `technique_name(tech)` helper (`t("technique.#{key}")`), used by the tags,
  the toggles, and the pill.

## Free-text preservation

`shared/_filter_panel` re-emits active filters as hidden fields when running a
free-text query, but only handles **string** params — an array `technique[]`
would be silently dropped. Extend it to re-emit array params as `key[]` entries.
(No other array filter exists today, so this is additive and safe.)

## Localization (all 19 locales)

- `lure.techniques` — cell/label header ("Techniques").
- top-level `technique:` map — `spinning`, `jigging`, `trolling`, `drifting`,
  `other`.

`no` locale keys stay quoted. (No placeholder key — the toggle group has no
combobox placeholder.)

## Tests

- `LureFilter`: single technique matches; multiple selected = OR union; unknown
  keys ignored; combined pill present.
- Lure edit: `technique_ids` persist for an admin; blank sentinel clears;
  member edit routes through moderation (assert the revision changeset carries
  `technique_ids`).

## Touch list

- Migration (2 tables + seed 5 rows)
- `app/models/technique.rb`, `app/models/lure_technique.rb`; `Lure` associations
- `app/helpers/taxonomy_helper.rb` — `technique_name`
- `app/queries/lure_filter.rb` — `ATTRS`, `apply_catalog`, `technique_keys`, pill
- `app/controllers/lures_controller.rb` — permit `technique_ids: []` + strip blanks
- `app/views/lures/_search.html.erb` — techniques toggle cell
- `app/views/lures/_form.html.erb` — techniques toggle cell
- `app/views/lures/show.html.erb` — technique tags
- `app/views/shared/_filter_panel.html.erb` — array param preservation
- 19 locale files — `lure.techniques`, `technique.*` (5)
- `db/seeds.rb` — assign techniques to the sample Vision 110
- Tests above
