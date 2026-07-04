# Color ↔ build availability (open-world matrix)

## Problem

A lure's colors (`Variant`) and sizes (`Build`) are independent axes with no
link between them, so the catalog implicitly claims **every color exists in
every build**. Production shows this is wrong for exactly the lures we carry:
DUO publishes a separate color chart per size, and e.g. Tide Minnow Slim's 129
colors are the *union* across its 8 builds. The lure page renders the identical
builds table under every color, and the catch picker offers every color × build
pairing — we display product combinations that were never manufactured.

## History: this reverses a settled decision — deliberately

The `variant_builds` matrix existed and was dropped on 2026-06-28
(`c753260`, Part B of the catalog simplification) because it cost "a join
table, a dual-reconciling picker, and an availability JSON contract" while the
data was a **closed-world** constraint nobody would curate: an unchecked box
meant *not available*, so 129-color imports needed a fully maintained 129×8
matrix or the page lied in the other direction.

What's different now:

1. **Open-world semantics.** No rows for a color = "availability unknown —
   show it everywhere" (today's behaviour, unchanged). Rows = "confirmed
   available in exactly these builds". Nothing needs backfilling; the matrix
   only ever *adds* precision where a contributor confirms it.
2. **One-directional picking.** Color filters builds; builds never filter
   colors. No dual reconciliation.
3. **Tiny JSON delta.** `build_ids` on a color is `null` (unknown) or an array
   — not a parallel availability hash.

## Data model

Restore the join table exactly as it was (the dropped migration is the
template, reversed):

```ruby
create_table :variant_builds do |t|
  t.references :variant, null: false, foreign_key: true
  t.references :build, null: false, foreign_key: true
  t.timestamps
end
add_index :variant_builds, [ :variant_id, :build_id ], unique: true
```

- `VariantBuild` model: `belongs_to :variant`, `belongs_to :build`,
  uniqueness of `variant_id` scoped to `build_id`.
- `Variant`: `has_many :variant_builds, dependent: :destroy`,
  `has_many :builds, through: :variant_builds`.
- `Build`: `has_many :variant_builds, dependent: :destroy`,
  `has_many :variants, through: :variant_builds`. Deleting a build cleans its
  rows — no dangling ids (the reason a join table beats a JSON `build_ids`
  column on `Variant`).

### Open-world resolution

```ruby
# Variant
def availability_known? = variant_builds.loaded? ? variant_builds.any? : variant_builds.exists?

# The builds this color is shown with: confirmed subset, else all of the lure's.
def available_builds
  availability_known? ? builds.ordered : lure.builds.ordered
end
```

Confirming *all* builds is representable (rows for every build) and renders the
same as unknown — that's fine; the distinction only matters to editors.

No `Catch` validation against the matrix. Catches are ground truth: a catch on
an unconfirmed combination is evidence the matrix is wrong, not the catch.
The existing "build belongs to the same lure as the variant" validation stays.

## Editing & moderation — reuse `commit_edit`, zero new machinery

`build_ids` rides through the existing `Editable` flow as a plain attribute:

- `Editable#build_changeset` already has the `_ids` branch (sorted integer
  arrays) — it survived the Part B removal and goes back to work unchanged.
- Admin/brand-owner path: `record.update(build_ids: [...])` writes the matrix
  directly via the association setter.
- Everyone else: the changeset lands in a `Revision` + `ModerationItem`;
  `ModerationItem#apply_edit!` (`subject.update!(attrs)`) applies or rolls back
  the array like any other field.

**Variant form** (`variants/_form.html.erb`): restore the build checkboxes from
`c753260^`, with copy updated for open-world semantics — label "Available
sizes", hint "Tick the sizes this color is confirmed to come in. Leave all
unticked if unknown (the color is shown for every size)." The blank
`hidden_field_tag "variant[build_ids][]"` returns so unchecking everything
submits `[]` — which now means *back to unknown*, not *available nowhere*.
"Available in no builds" is deliberately unrepresentable.

**Variant params** (`variants_controller#variant_params`): re-permit
`build_ids: []`, strip blanks (also restored from `c753260^`).

**Moderation diff**: changeset arrays of opaque ids are unreadable in review.
The variant diff preview renders `build_ids` changes as build *names*
(`Build.where(id: ids)` lookup, mirroring how `_diff_preview` humanizes
`brand_id`/`lure_type_id`), shown as before/after chip lists.

## Display

**Lure page, Variations tab** (`lures/show.html.erb`): each color's builds
table renders `variant.available_builds` instead of the flat `@builds`. When
the list is a confirmed subset, a muted caption under the table: "Available in
N of M sizes"; when unknown, no caption (don't advertise ignorance on every
row). Load `variants` with `variant_builds` included to keep this N+1-free.

**`lures#variations` JSON**: each color gains
`build_ids: null | [int]` (`null` = unknown). `builds` stays the flat ordered
list. One nullable key, not a contract.

**Catch picker** (`catch_picker_controller.js`): `populateBuilds` filters the
build select to the chosen color's `build_ids` when non-null; shows all builds
when null. Re-filter on `colorChanged`, preserving the current selection if it
survives the filter (logic recoverable from `c753260^`). Colors are never
filtered by build — one direction only.

## Seeds & import

- `db/seeds.rb`: give one seed lure a partial matrix (one exclusive color, the
  rest unknown) so dev exercises both code paths.
- The brand-import workflow scrapes per-size color charts anyway; a follow-up
  can emit `variant_builds` rows during import. Out of scope here, but the
  open-world default means imports that skip it stay correct-as-unknown.

## i18n

New keys (`lure.availability`, `lure.availability_hint`,
`lure.available_in_n_of_m`) in the four fully translated locales
(en, de, bg, ja); the six stubs fall back to English.

## Tests

- Model: unknown → `available_builds` = all of the lure's; confirmed →
  subset; destroying a build removes its rows and widens back correctly;
  uniqueness of the pair.
- `variations_flow_test`: JSON ships `null` vs array; lure page shows the
  filtered table plus caption for a confirmed color and the full table for an
  unknown one.
- Editable: a non-admin `build_ids` suggestion creates a Revision whose
  approval applies the matrix, and rollback restores the prior array.

## Out of scope

- Backfilling availability for the 1,959 existing colors (open-world makes
  this optional forever).
- Filtering colors by build (the reverse direction), and any availability
  editing from the build side.
- Per-combination data (SKU codes, per-size pricing) — the join row stays
  bare.
- Catch validation against the matrix.
