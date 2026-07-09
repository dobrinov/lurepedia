# Hooks filter — implementation plan

Spec: `docs/superpowers/specs/2026-07-09-hooks-filter-design.md`

1. **Migration**: `AddHookTypeToBuilds` — `add_column :builds, :hook_type,
   :integer` (nullable). Migrate, restart the 3939 dev server.

2. **Model**: `Build` — `enum :hook_type, { none: 0, single: 1, treble: 2 },
   prefix: :hook`.

3. **Helper**: `TaxonomyHelper#hook_type_name(key)` → `t("hook.#{key}")`.

4. **Filter** (`LureFilter`): add `:hook` to `ATTRS`; in `apply_catalog`,
   `scope.where(id: Build.where(hook_type: @p[:hook]).select(:lure_id))` guarded
   by a `hook?` predicate (`Build.hook_types.key?`); add a `:hook` pill.

5. **Search panel** (`SearchFiltersHelper`): add `:hook` to `STATIC_FILTERS`;
   options `Build.hook_types.keys.map { |k| [ hook_type_name(k), k ] }`;
   `filter_label` → `t("lure.hooks")`; `filter_placeholder` → `t("search.any_hooks")`.

6. **Edit**: `builds_controller` `build_params` permit `:hook_type` and
   normalize blank → nil; `builds/_form` a `hook_type` select after Water with
   `include_blank` for "unknown".

7. **Display**: `lures/show` variations table — a Hooks column
   (`t("lure.hooks")` header) rendering `hook_type_name(b.hook_type)` or
   `t("common.none")`.

8. **Locales** (all 19): `lure.hooks`, `search.any_hooks`, `hook.none/single/treble`.
   `no` keys quoted.

9. **Seeds**: give a seeded Vision 110 build a `hook_type`.

10. **Tests**: `LureFilter` — filter by hook, ignore unknown, pill present,
    any-build-matches. `bin/rubocop` + `bin/rails test`.
