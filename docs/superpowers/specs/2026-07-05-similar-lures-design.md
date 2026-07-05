# Similar lures (cross-brand references + upload-time proposals)

## Problem

Look-alike lures from different brands are everywhere — near-identical
minnows, spoons and cranks sold under different names. The catalog has no way
to say "these two are comparable", so an angler who finds a proven lure can't
discover its cheaper or locally-available twins, and contributors who *know*
two models match have nowhere to record it.

Two deliverables:

1. **A symmetric cross-reference** between any two lures ("similar lures"),
   contributed like any other catalog entry and shown on both lure pages.
2. **Automatic proposals at upload time**: when a contributor uploads a color
   photo, compare its color distribution against the existing catalog and
   offer the closest matches as one-tick link suggestions.

## Data model

```ruby
create_table :lure_links do |t|
  t.references :lure, null: false, foreign_key: true
  t.references :related_lure, null: false, foreign_key: { to_table: :lures }
  t.timestamps
end
add_index :lure_links, [ :lure_id, :related_lure_id ], unique: true
```

- `LureLink` is **symmetric**: one row per pair, normalized lower-id-first in
  a `before_validation`, so the reverse duplicate collides with the unique
  index instead of needing a two-way uniqueness check. Self-links are invalid.
- `LureLink` includes `Publishable`: a member's link is created live but stays
  hidden until a catalog `ModerationItem` is approved — the same lifecycle as
  a new color or build. **Only admins create links directly**: a link touches
  *two* brands, so a verified owner of one brand doesn't get unreviewed writes
  that name-drop another brand's lure (`can_add_directly?` deliberately does
  not apply).
- `Lure#similar_lures(links:)` resolves both directions of the pair into a
  `Lure` relation; callers pass `LureLink.published` (default) or `.all` for
  moderators, and wrap the result in `visible_catalog` so unpublished lures
  never surface.
- Deleting a lure destroys its links from both sides (two `has_many`s with
  `dependent: :destroy`).

## Color-distribution matching

### Signature

`ColorSignature` (app/services) fingerprints a photo:

- resample to 32×32 via ImageMagick's `txt:` dump (the same technique
  `TileBackgroundAnalyzer` already uses);
- drop transparent pixels and pixels within Euclidean RGB distance 60 of the
  image's own border average — catalog shots are lures on flat studio
  backgrounds, and without this the background dominates every histogram;
- bin the surviving pixels into a 4×4×4 RGB histogram (64 bins), normalize to
  a 0–255 share per bin, serialize as 128 hex chars;
- similarity = histogram intersection (Σ min / Σ), 0..1;
- bail out (nil) when fewer than 10% of pixels survive background removal —
  a near-solid image has no usable signature.

### Storage: blob metadata, no schema change

`TileBackgroundAnalyzer` gains a `color_signature` key next to
`background_color`, stored in Active Storage blob metadata by the existing
`AnalyzeJob` on attach. Same `false`-when-unusable convention, same backfill
task (`images:backfill_backgrounds` now also fills signatures). Rationale: the
signature describes *one specific image* exactly like the background color
does, and reusing the analyzer means zero new jobs, columns or callbacks.

### Proposal flow

`POST /lures/:lure_id/similar-preview` (login + catalog contribution
required): receives the picked photo file, computes its signature
synchronously (~tens of ms on a 32×32 resample), and ranks candidates via
`SimilarLureSuggestions` (app/queries): best per-lure similarity across all
published variants' stored signatures, threshold 0.5, top 4, published lures
only, current lure excluded. Returns JSON cards (slug, title, brand, thumb,
translated match label).

The new-color form (`variants/new`) wires a `similar-lures` Stimulus
controller to the existing photo input: on file pick/drop it posts the file
and renders the returned matches as checkboxes named `similar_lure_slugs[]`.
`VariantsController#create` turns ticked slugs into `LureLink`s under the same
moderation gating (admin → live, everyone else → one catalog item per link).
The signature comparison is *only* a suggestion engine — nothing is linked
without an explicit human tick.

## UI

- **Lure page**: a "Similar lures" card grid (existing `shared/_lure_card`,
  `grid-cards`) under the tabbed section; moderators also see links still in
  review.
- **Lure edit → manage tab**: a "Similar lures" card listing linked lures
  (pending badge for unapproved links, remove button for moderators) plus an
  add form using the existing async combobox against `/options/lures`.
- **Moderation queue**: links ride the existing catalog kind;
  `moderation_title` renders "A ↔ B".

## Out of scope

- Shape/profile matching (would need contour analysis; color distribution is
  the 80% win the catalog's studio-shot photos support well).
- Auto-linking without human confirmation.
- Ranking similar lures by proven-ness (future: sort the section by
  `catches_count`).
