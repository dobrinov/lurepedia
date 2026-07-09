# Techniques filter — implementation plan

Spec: `docs/superpowers/specs/2026-07-09-techniques-filter-design.md`

1. **Migration** `CreateTechniques`: `techniques` (key, unique) + `lure_techniques`
   (lure_id, technique_id, unique pair, FKs); insert the 5 fixed rows
   (spinning/jigging/trolling/drifting/other) via `execute`. `down` drops both.
   Migrate, restart the 3939 dev server.

2. **Models**: `Technique` (mirrors `LureType`: key validation, `#name` via
   `technique.<key>`, `to_param`, `has_many :lures, through:`); `LureTechnique`
   (belongs_to lure + technique); `Lure` — `has_many :lure_techniques,
   dependent: :destroy; has_many :techniques, through:`.

3. **Helper**: `TaxonomyHelper#technique_name(tech)` → `t("technique.#{key}")`.

4. **Filter** (`LureFilter`): add `:technique` to `ATTRS`; a `technique_keys`
   helper (intersect params with real keys); `apply_catalog` clause matching any
   selected technique via the join; a combined `:technique` pill (joined names).

5. **Search panel** (`lures/_search`): a techniques cell — `.stack` of `.toggle`
   switches named `technique[]` by key.

6. **Edit** (`lures/_form` + controller): toggle switches named
   `lure[technique_ids][]` by id + blank hidden sentinel; `lure_params` permit
   `technique_ids: []` and strip blanks.

7. **Display** (`lures/show`): one `.tag` per technique after the material tag.

8. **Free-text preservation** (`shared/_filter_panel`): re-emit array params as
   `key[]` hidden fields.

9. **Locales** (all 19): `lure.techniques`, `technique.{spinning,jigging,trolling,drifting,other}`.

10. **Seeds**: assign a couple of techniques to the sample Vision 110.

11. **Tests**: `LureFilter` single/multi(OR)/unknown/pill; lure edit persistence
    of `technique_ids`. `bin/rubocop` + `bin/rails test`.
