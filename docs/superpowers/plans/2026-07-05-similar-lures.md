# Similar lures — implementation plan

Spec: `docs/superpowers/specs/2026-07-05-similar-lures-design.md`

1. **Schema + model**: `lure_links` migration; `LureLink` (Publishable,
   lower-id-first normalization, self-link + pair uniqueness validations,
   `#other_lure`); `Lure` associations + `#similar_lures(links:)`.
2. **Signature engine**: `ColorSignature` service (compute / parse /
   similarity); `TileBackgroundAnalyzer` stores `color_signature` in blob
   metadata; `images:backfill_backgrounds` also backfills signatures;
   `Variant#color_signature` reader.
3. **Suggestions**: `SimilarLureSuggestions` query (best-variant-match per
   lure, threshold 0.5, top 4, published only).
4. **Controllers + routes**: `LureLinksController` (`create`, `destroy`,
   `preview`) under `lures/:lure_id`; `VariantsController#create` links ticked
   `similar_lure_slugs[]`.
5. **UI**: lure show section (`grid-cards` of `_lure_card`); edit-page manage
   card (list + async combobox add); `similar_lures_controller.js` proposal UI
   in the new-color form; `moderation_title` case.
6. **Locales**: seven `lure.similar_*` keys in all ten files.
7. **Tests**: `LureLink` model, `ColorSignature` service, `LureLinks`
   controller (member vs admin gating, preview matching end-to-end with
   generated images).
