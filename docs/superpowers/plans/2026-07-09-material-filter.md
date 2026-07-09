# Material filter — implementation plan

Spec: `docs/superpowers/specs/2026-07-09-material-filter-design.md`

1. **Migration**: `AddMaterialToLures` — `add_column :lures, :material, :integer`
   (nullable, no default). Migrate, restart the 3939 dev server.

2. **Model**: `Lure` — `enum :material, { plastic: 0, composite: 1, wood: 2,
   metal: 3, silicone: 4, other: 5 }, prefix: :material`.

3. **Helper**: `TaxonomyHelper#material_name(key)` → `t("material.#{key}")`,
   mirroring `lure_type_name`/`water_name`.

4. **Filter** (`LureFilter`): add `:material` to `ATTRS`; in `apply_catalog`,
   `scope.where(material: @p[:material])` guarded by `Lure.materials.key?`; add a
   `:material` pill in `active_pills` labelled via `material_name`.

5. **Search panel** (`SearchFiltersHelper`): add `:material` to `STATIC_FILTERS`;
   `static_filter_options` case → `Lure.materials.keys.map { |k| [ material_name(k), k ] }`;
   `filter_label` → `t("lure.material")`; `filter_placeholder` → `t("search.any_material")`.

6. **Edit**: `lures_controller` `lure_params` permit `:material`;
   `lures/_form` a material inline combobox (like the type field) with a blank
   "unknown" option.

7. **Display**: `lures/show` chips row — a `.tag` with `material_name(@lure.material)`
   only when material is present.

8. **Locales** (all 19): `lure.material`, `search.any_material`, and
   `material.plastic/composite/wood/metal/silicone/other`. `no` keys quoted.

9. **Seeds + samples**: give the seeded Vision 110 a material; add
   `material:` to a `DesignSystem::SampleData` lure if the styleguide renders the tag.

10. **Tests**: `LureFilter` — filter by material, ignore unknown values, pill
    present. `bin/rubocop` + `bin/rails test`.
