# Plan: image crop tool for catalog photos

Spec: `docs/superpowers/specs/2026-07-04-image-crop-tool-design.md`

## Steps

1. **Migration** — `photo_crop_x/y/w/h` (integer, nullable) on `variants` and
   `species`.

2. **`Croppable` model concern** (`app/models/concerns/croppable.rb`) —
   included by `Variant` and `Species`:
   - `photo_crop?` / `photo_crop_geometry` (`"WxH+X+Y"` or nil).
   - Validation: crop fields all-or-none; `w`/`h` >= 1, `x`/`y` >= 0.
   - `before_save`: attaching a different photo clears a crop that wasn't set
     in the same save.

3. **Helper** — `ApplicationHelper#cropped_photo(record, **transformations)`
   returns `photo.variant` with `crop` + `+repage` prepended when a crop is
   set. Swap in at every variant/species photo render site: `_lure_card`,
   `lures/show` (stage, tile `data-photo-url`, tile thumbs), `lures/edit`
   thumbs, `lures/_diff_preview`, `variants/_form` thumb, `species/index`,
   `species/show` (card + lightbox), `species/_form` thumb,
   `species/_diff_preview`.

4. **UI** — `shared/_image_cropper` partial (hidden fields + toggleable
   editor), `image_crop_controller.js` Stimulus controller (pointer-event
   move/resize, aspect presets, reset), `.crop-*` styles in `application.css`.
   Render from `variants/_form` and `species/_form`.

5. **Params & i18n** — permit the four crop fields in `VariantsController`
   and `SpeciesController`; add `crop.*` strings to all 10 locale files.

6. **Tests** — model tests for geometry/validation/reset-on-replace;
   controller test that a member's crop edit lands as a pending revision and
   an admin's applies directly. Run `bin/rails test` + `bin/rubocop`.

## Verified up front

`image_processing` 2.0 + mini_magick accepts
`{ crop: "400x250+100+50", append: "+repage", resize_to_limit: [...] }` and
produces a correctly sized, repaged image (checked against a generated
gradient PNG). Hash order is preserved through `ActiveStorage::Variation`.
