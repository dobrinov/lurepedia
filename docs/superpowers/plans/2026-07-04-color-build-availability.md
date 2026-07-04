# Color ↔ build availability — Plan

Date: 2026-07-04
Spec: `docs/superpowers/specs/2026-07-04-color-build-availability-design.md`
Branch base: `main`

## Goal

Reintroduce the color↔build matrix with **open-world semantics** (no rows =
unknown = show everywhere), in three self-contained parts, each its own commit
with green tests. Much of the code is restored from `c753260^` (the commit
before Part B of the catalog simplification dropped the old matrix) — diff
that commit before writing anything from scratch.

Key deviations from the old implementation, established in the spec:

- Zero rows means *unknown*, never *unavailable*. All fallbacks flow from this.
- Picker filtering is one-directional (color → builds), restored as it was.
- No catch validation against the matrix.

---

## Part 1 — schema, model, open-world resolution

**Migration** `db/migrate/..._create_variant_builds.rb` — reverse of
`20260628000005_drop_variant_builds.rb`:

```ruby
create_table :variant_builds do |t|
  t.references :variant, null: false, foreign_key: true
  t.references :build, null: false, foreign_key: true
  t.timestamps
end
add_index :variant_builds, [ :variant_id, :build_id ], unique: true
```

**Models**

- `app/models/variant_build.rb` — restore verbatim from `c753260^`
  (`belongs_to` both sides, uniqueness of `variant_id` scoped to `build_id`).
- `Variant` — `has_many :variant_builds, dependent: :destroy`,
  `has_many :builds, through: :variant_builds`, plus:

  ```ruby
  # Whether contributors have confirmed which builds carry this color.
  def availability_known?
    variant_builds.loaded? ? variant_builds.any? : variant_builds.exists?
  end

  # The builds this color is shown with: the confirmed subset, else — open
  # world — every build of the lure.
  def available_builds
    availability_known? ? builds.ordered : lure.builds.ordered
  end
  ```

- `Build` — `has_many :variant_builds, dependent: :destroy`,
  `has_many :variants, through: :variant_builds` (deleting a build must clean
  its rows; a widened `available_builds` is the observable effect).

**Seeds** (`db/seeds.rb`): the seed lures get one "Standard" build each; give
the first spec lure (Megabass Vision Oneten, 3 colors) a second build
("Jr", smaller length/weight) and confirm exactly one of its colors to the
Standard build only. One lure exercising both code paths is enough — don't
matrix every seed lure. Keep `db:seed` idempotent (`find_or_create_by!` on the
join like the rest of seeds).

**Tests** (`test/models/catalog_test.rb`, alongside the existing build/depth
tests):

- unknown availability → `available_builds` returns all of the lure's builds,
  ordered.
- confirmed subset → returns exactly the confirmed builds; adding a new build
  to the lure does *not* widen a confirmed color, but does widen an unknown one.
- destroying a build destroys its `variant_builds` rows; a color confirmed
  only to that build reverts to unknown (falls back to all remaining builds).
- duplicate (variant, build) pair is invalid.

Commit: `Restore variant_builds as an open-world availability matrix`

---

## Part 2 — editing & moderation

**Variant form** (`app/views/variants/_form.html.erb`) — restore the checkbox
block from `c753260^` between the photo field and submit, with new copy:

- label: `t("lure.availability")` ("Available sizes")
- hint under the label: `t("lure.availability_hint")` ("Tick the sizes this
  color is confirmed to come in. Leave all unticked if unknown — the color is
  shown for every size.")
- keep the blank `hidden_field_tag "variant[build_ids][]", ""` — submitting
  with nothing ticked writes `[]`, i.e. *back to unknown*. There is no
  "available nowhere" state.
- render only when `@lure.builds.any?` (as before).

**Params** (`variants_controller#variant_params`) — restore from `c753260^`:
permit `build_ids: []`, reject blanks. This covers both `create` (a new color
can be born with confirmed builds; direct assignment, no changeset) and
`update` (flows into `commit_edit`).

**Moderation plumbing — verify, don't build.** `Editable#build_changeset`
already has the `_ids` branch (sorted int arrays), and
`ModerationItem#apply_edit!` applies `build_ids` via the association setter.
No changes expected; the tests below prove it.

**Moderation diff rendering.** Variant revisions render through the generic
`shared/_diff` fallback (there is no variant diff-preview partial — see
`RevisionsHelper#diff_preview_partial`). Two touches in
`app/helpers/revisions_helper.rb`:

- `diff_field_label`: add `revision.field.build_ids` locale key ("Available
  sizes") so the label doesn't come out as the auto-humanized "Builds".
- Where the shared diff renders changeset values (`diff_value`), special-case
  `build_ids` arrays: map ids to build names via `Build.where(id: ids)` and
  join (" · "), falling back to the id for a since-deleted build. Follow how
  `shared/_diff` passes field context — if `diff_value` doesn't receive the
  field name, do the mapping in the partial instead.

**i18n**: add `lure.availability`, `lure.availability_hint`,
`revision.field.build_ids` to en, de, bg, ja (the six stub locales fall back
to English — check `locale_parity_test` expectations).

**Tests** (`test/integration/variations_flow_test.rb`):

- admin edits a color's `build_ids` directly → matrix rows written, revision
  changeset records `[old_ids, new_ids]`.
- member suggests a `build_ids` change → record untouched, Revision +
  ModerationItem created; approving applies the matrix; undo restores the old
  array (exercise `apply_edit!` both directions).
- new color created with ticked builds gets its rows immediately.
- moderation queue page shows build *names*, not raw ids, for a pending
  `build_ids` suggestion.

Commit: `Edit color availability through the standard suggestion flow`

---

## Part 3 — display: lure page, variations JSON, catch picker

**Lure page** (`lures_controller#show` + `lures/show.html.erb`):

- eager-load the matrix: add `:variant_builds` to the `@lure` includes so
  `availability_known?` runs off the loaded association (no N+1 across 129
  colors).
- in the Variations tab, replace the flat `@builds.each` inside each color's
  table with the color's list **intersected against `@builds`** — `@builds`
  is already `visible_catalog`-filtered, and a raw `variant.available_builds`
  would resurrect hidden builds:

  ```ruby
  # helper or inline: builds shown for a color, respecting catalog visibility
  builds_for = v.availability_known? ? @builds.select { |b| v.build_ids.include?(b.id) } : @builds
  ```

- when the list is a confirmed subset (`builds_for.size < @builds.size` and
  known), render a muted caption under the table:
  `t("lure.available_in_n_of_m", n:, m:)`. No caption for unknown colors.
- edge: a confirmed color whose intersection with visible builds is empty
  renders the existing `catch.no_builds` empty state, not a zero-row table.

**Variations JSON** (`lures_controller#variations`):

- add `:variant_builds` to the includes.
- each color gains `build_ids: v.availability_known? ? v.build_ids.sort : nil`.
  `builds` stays the flat ordered list.

**Catch picker** (`app/javascript/controllers/catch_picker_controller.js`) —
restore the pre-`c753260` shape, adapted to open-world:

- `populateBuilds()` takes the currently selected color; when that color's
  `build_ids` is non-null, filter `this.variations.builds` to it; when null
  (or no color chosen), offer all builds. Update the stale "Every build of the
  lure is offered" comment.
- add `colorChanged` action on the color select (wire in
  `catches/new.html.erb`): re-run `populateBuilds()`, preserving the current
  build selection if it survives the filter, else reset to the placeholder.
- preselection from query params must apply color *before* builds so a
  preselected build isn't dropped by the filter.
- colors are never filtered by build.

**i18n**: `lure.available_in_n_of_m` in en, de, bg, ja.

**Tests** (`test/integration/variations_flow_test.rb`):

- update "variations endpoint returns colors and builds independently":
  unknown color → `build_ids` is null; confirmed color → the sorted array.
- lure page: confirmed color's table lists only its builds plus the caption;
  unknown color's table lists all builds, no caption.
- a moderation-hidden build appears in no color's table even if confirmed.

Commit: `Filter builds per color on the lure page and catch picker`

---

## Verification (after Part 3)

- `bin/ci` green.
- `bin/rails db:seed:replant`, then in the browser (`bin/dev`): the seeded
  Megabass lure shows the confirmed color limited to Standard with the
  "1 of 2" caption, its sibling colors showing both builds; log-a-catch picker
  narrows the build select when that color is chosen and un-narrows on a
  sibling.
- Suggest a `build_ids` edit as a member, approve it in `/moderation` as
  admin, confirm the diff shows build names and the lure page narrows.

## Explicitly not in this plan

- Backfill of the 1,959 production colors (open-world default covers them).
- Import-pipeline emission of `variant_builds` rows (follow-up to the
  brand-import workflow).
- Build-side editing, reverse filtering, per-combination SKU data, catch
  validation against the matrix.
