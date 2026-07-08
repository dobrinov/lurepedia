# Glow / UV split — implementation plan

Spec: `docs/superpowers/specs/2026-07-08-glow-uv-split-design.md`

1. **Migration**: `SplitVariantUvGlow` — add `variants.glow` and `variants.uv`
   (boolean, default false, null false); backfill `UPDATE variants SET uv =
   uv_glow`; drop `uv_glow`. Reversible `down` restores `uv_glow` from `uv`.
   Run migrate, then restart the 3939 dev server (stale schema cache drops
   new-column writes otherwise).

2. **Write path**:
   - `VariantsController` permitted params `:uv_glow` → `:glow, :uv`
     (create + update; the edit funnels through `Editable#commit_edit`
     unchanged).
   - `LuresController#variations` JSON: `uv_glow: v.uv_glow` →
     `glow: v.glow, uv: v.uv`.

3. **Filter**: `LureFilter` — add `glow`, `uv` to `ATTRS`; in `apply_catalog`
   two `truthy?`-gated clauses matching any-variant-has-flag
   (`scope.where(id: Variant.where(glow: true).select(:lure_id))`, same for
   `uv`); add pills in `active_pills` labelled from `lure.glow` / `lure.uv`.

4. **Views + JS**:
   - `variants/_form.html.erb`: two checkboxes (`glow`, `uv`) with labels + a
     one-line hint distinguishing dark-glow from UV-reactive.
   - `lures/show.html.erb`: split the single `uv_glow` UV badge into UV (`uv`)
     and GLOW (`glow`) badges at all three sites (chip, lightbox, tile); emit
     `data-glow` alongside `data-uv` on the color tile.
   - `variant_stage_controller.js`: add `chipGlow` / `lightboxGlow` targets
     mirroring the UV plumbing.
   - `lures/edit.html.erb`: split the color-list badge.
   - CSS: `.glow-badge` sibling of `.uv-badge`, distinct colour.

5. **Search panel**: two checkboxes in the filter form next to water/action;
   absent = unconstrained.

6. **Locales**: in all 19 files replace the single `lure.uv_glow` key with
   `lure.uv` (inherits the old UV translation) and `lure.glow` (fresh
   phosphorescence-sense translation, glow-in-the-dark not "shine"). Keep
   `no`'s keys quoted.

7. **Seeds + samples**: `db/seeds.rb:200` set `glow`/`uv` instead of `uv_glow`;
   optionally give a `DesignSystem::SampleData` colour a glow/UV flag so the
   styleguide shows both badges.

8. **Tests**:
   - Migration backfill: pre-existing `uv_glow`-true colour → `uv: true,
     glow: false`.
   - `LureFilter`: `glow=1` returns only glow lures, `uv=1` only UV lures, the
     two independent.
   - Update `variations_flow_test` fixtures/assertions (`uv_glow` → both
     fields) and assert both JSON keys.
   - `bin/rubocop` + `bin/rails test`.
