# Image crop tool for catalog photos

## Problem

Uploaded catalog photos (variant/color photos on lure cards, species photos)
arrive in arbitrary aspect ratios. Cards render them `resize_to_limit` inside a
fixed 8:5 frame, so badly framed uploads waste the frame or show distracting
background. Contributors need a way to crop a photo **after** upload so previews
fill their frames well — without destroying the original file.

## Approach: non-destructive crop stored on the record

The crop is a rectangle in original-image pixel coordinates, stored as four
nullable integer columns on the owning record:

```
photo_crop_x  photo_crop_y  photo_crop_w  photo_crop_h
```

Applied to **Variant** and **Species** (the two catalog models whose photos
drive card previews). Brand logos, avatars, and catch photos are out of scope.

Rendering goes through a helper that prepends the crop to any variant request:

```ruby
cropped_photo(record, resize_to_limit: [ 560, 350 ])
# => photo.variant(crop: "WxH+X+Y", append: "+repage", resize_to_limit: [ 560, 350 ])
```

`+repage` clears ImageMagick's retained virtual-canvas offset. When no crop is
set the helper degrades to a plain `variant(...)` call. The original blob is
never modified, so a crop can be adjusted or removed at any time and Active
Storage regenerates variants (the crop participates in the variation digest).

### Why plain columns

Because the crop is ordinary record attributes, it flows through the existing
`Editable#commit_edit` machinery untouched: admins/brand owners crop directly,
everyone else's crop becomes a `Revision` + `ModerationItem` suggestion, and
changeset apply/rollback (`ModerationItem#apply`) works field-by-field exactly
as for text edits. No new moderation or provenance code.

### Lifecycle rules

- All four values must be present together (or all nil); `w`/`h` >= 1,
  `x`/`y` >= 0. Out-of-bounds rectangles are harmless — ImageMagick clips.
- Replacing the photo resets the crop, **unless** the same save also sets crop
  values (so a changeset carrying photo + crop applies both).

## Crop editor UI

A shared partial `shared/_image_cropper` rendered inside the existing variant
and species forms when a photo is attached:

- Four hidden fields carry the crop; submitting the form routes them through
  the normal `commit_edit` path (crop = just another suggested edit).
- An "Adjust crop" button expands an inline editor: the **original** image
  (`url_for(photo)`, so client pixel math uses true `naturalWidth`) under a
  draggable/resizable crop box with a dimmed surround.
- Hand-rolled Stimulus `image-crop` controller (no external library, per house
  style): pointer-events drag to move, corner handles to resize, aspect presets
  — Free and Square (1:1, matching the square image frames used app-wide).
- "Reset" clears the hidden fields (removes the crop on save); "Done" collapses
  the editor. The crop takes effect after the form is saved/approved.

## i18n

New `crop.*` keys (adjust / done / reset / aspect labels / hint / invalid)
added to the four fully translated locale files (en, de, bg, ja); the other
six are stubs that fall back to English.

## Out of scope

- Cropping brand logos, user avatars, catch photos (mechanism is reusable if
  wanted later).
- Client-side preview of the resulting card (the crop box itself is the
  preview).
