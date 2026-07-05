# Catch conditions summary on lure pages

**Date:** 2026-07-05 · **Status:** implemented

## Problem

A lure page's unique, defensible content is its catch evidence — species and
conditions no retailer or manufacturer page can replicate. Today that data is
invisible to search: catch cards live on the `caught` tab, tab URLs
canonicalize to the base lure URL, and the default tab is `variations`, so
the canonical page contains no catch text at all. The cards also show only
the 8 most recent catches, never the aggregate picture.

## Design

An always-visible "What the catches show" panel on `lures/show`, rendered
between the hero and the tabs (outside tab switching, so it is on the
canonical URL for every tab/color variant). Shown only when the lure has
catches — unproven lures keep their current layout.

Content, aggregated over **all** of the lure's catches:

- Total catch count (existing pluralized `lure.catches_count` key).
- Top species (up to 4) with counts, each linking to the species page —
  internal linking from lures into the species graph.
- Per condition group (season, water body, clarity, time of day, wind,
  platform, retrieve): the top values (up to 3) with counts, labelled with
  the existing `condition.<group>.label` / `condition.<group>.<value>` keys.
  Groups with no data are omitted.

Counts render as `×N` chips — language-neutral, no new plural rules.

## Implementation

- `LureCatchSummary` query object (`app/queries/`), following the house
  query-object pattern: one grouped count per condition group plus one for
  species. No caching yet; revisit with fragment caching if lure pages get
  hot.
- Two new locale keys (`lure.proven_record.title`, `.top_species`) in all
  ten locale files. Everything else reuses existing translations.

## Non-goals

- No per-variant/per-build breakdown (the color/build axes stay on their
  tabs).
- No structured-data changes — the panel is crawlable HTML text; the
  Product JSON-LD stays as is.
- Never validate or filter the summary against the variant×build
  availability matrix (open-world rule).
