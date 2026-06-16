# Searchable, paginated filter dropdowns

## Problem

The lure search filter panel (`app/views/layouts/_search.html.erb`) renders empty
`select_tag` controls — no options are ever loaded. We want every filter dropdown
populated and searchable, and the dropdowns backed by large collections must page
in their options (load page 1, fetch more on scroll, re-query on search term)
rather than loading everything up front.

## Approach: two dropdown types

The data splits cleanly into large, growable collections and tiny static enums, so
we use two mechanisms.

### Large collections — `async_combobox` (new)
For `species` and `brands`. Server-backed: loads page 1 on open, fetches the next
page on scroll-to-bottom, and re-queries the server (page 1) when the user types.
Reuses the existing combobox markup/CSS for visual consistency.

### Small static enums — existing `combobox` (reused)
For `type`, `lure_action`, `season`, `clarity`, `water_body`, `wind`, `depth`.
Options are rendered inline as JSON; the existing client-side `combobox` controller
already filters them as you type. These lists are 3–7 items, so no pagination.

## Backend — options endpoints

New `FilterOptionsController`, routed under the locale scope:

```ruby
get "options/species", to: "filter_options#species"
get "options/brands",  to: "filter_options#brands"
```

Each action returns JSON `{ results: [{ value:, label: }], next_page: <n|null> }`.
Page size **20**. Params: `q` (search term), `page` (1-based).

- **Brands** — DB-level and fully scalable: `WHERE LOWER(name) LIKE ?`,
  `ORDER BY name`, `LIMIT/OFFSET`. `value` = slug, `label` = name.
  `next_page` is `page + 1` when a full page was returned, else `null`.
- **Species** — species names are I18n-derived from `key` (there is no `name`
  column), so search and sort happen in Ruby over the full species set (bounded
  reference data, same as the existing global search), then the array is sliced by
  page. This is locale-correct. The Ruby-pagination tradeoff is documented in a
  code comment. `value` = slug, `label` = `common_name`.

## Frontend — `async_combobox` Stimulus controller

Values: `url`, `selectedValue`, `selectedLabel`, `placeholder`.

- **Open** → fetch page 1 once (cached for the session of the open panel).
- **Search input** → 250ms debounce, reset to page 1 with `q`, replace the list.
- **Infinite scroll** → `IntersectionObserver` watches a sentinel element at the
  bottom of the options list. When it enters view and `next_page` is present and a
  fetch is not already in flight, load the next page and append.
- **Pick** → write the hidden field value + trigger label, dispatch `change`, close.
- Loading and empty states reuse `combobox-empty` styling.

When a filter is already active (e.g. `?species=largemouth-bass`), the partial
resolves the slug → label server-side so the trigger shows the current selection
immediately, without an initial fetch.

## Wiring `depth` (currently dead)

`depth` is listed in `LureFilter::ATTRS` but never applied, and lures only store a
depth range (`depth_min_cm` / `depth_max_cm`). We add static buckets and implement
the missing filter:

- **Shallow** 0–150 cm, **Mid** 150–450 cm, **Deep** 450 cm+.
- Defined as a constant `DEPTH_BANDS` in `LureFilter`, with I18n labels.
- Filtering is range-overlap: `depth_min_cm <= band_max AND depth_max_cm >= band_min`.
- Add a `depth` entry to `active_pills`.

## View / partial changes

`_search.html.erb`:
- `species` / `brand` → new async combobox, pointing at their endpoint and seeded
  with any active selection.
- `type`, `lure_action`, `season`, `clarity`, `water_body`, `wind`, `depth` →
  `shared/_combobox` with inline option arrays.
- A helper supplies the static enum option lists to keep the view clean.

## Testing

- `LureFilter` unit tests: depth-band overlap and `lure_action` filtering.
- `FilterOptionsController` tests: pagination boundaries, `q` search, `next_page`
  null on the last page — for both species and brands.
- JS controller: no JS test harness exists in the repo, so infinite scroll + search
  are verified manually in the running app.
