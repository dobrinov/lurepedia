# Filters lures by catalog attributes and (via catches) condition attributes.
class LureFilter
  ATTRS = %i[q type brand species lure_action depth length_min length_max weight_min weight_max weight_unit
             water_body season clarity wind water glow uv sort].freeze

  # Depth bands in centimetres, matched by overlap against a lure's [min, max] range.
  DEPTH_BANDS = { "shallow" => [ 0, 150 ], "mid" => [ 150, 450 ], "deep" => [ 450, 100_000 ] }.freeze

  # Range filters render one pill but span several query params; the pill's × must clear them all.
  PILL_PARAMS = { length: %w[ length_min length_max ], weight: %w[ weight_min weight_max weight_unit ] }.freeze

  def self.pill_params(key)
    PILL_PARAMS.fetch(key.to_sym, [ key.to_s ])
  end

  def initialize(params = {})
    @p = params.respond_to?(:to_unsafe_h) ? params.to_unsafe_h.symbolize_keys : params.symbolize_keys
  end

  def results
    scope = Lure.includes(:brand, :lure_type).published
    scope = apply_text(scope)
    scope = apply_catalog(scope)
    scope = apply_conditions(scope)
    apply_sort(scope.distinct)
  end

  # Active filters as [key, label] for rendering removable pills.
  def active_pills
    pills = []
    pills << [ :type, lure_type_label(@p[:type]) ] if present?(:type)
    pills << [ :brand, brand_label(@p[:brand]) ] if present?(:brand)
    pills << [ :species, species_label(@p[:species]) ] if present?(:species)
    pills << [ :lure_action, @p[:lure_action].to_s.titleize ] if present?(:lure_action)
    pills << [ :depth, I18n.t("search.depth_band.#{@p[:depth]}", default: @p[:depth].to_s.titleize) ] if present?(:depth) && DEPTH_BANDS.key?(@p[:depth].to_s)
    pills << [ :length, range_label(:length_min, :length_max, "mm") ] if range?(:length_min, :length_max)
    pills << [ :weight, range_label(:weight_min, :weight_max, I18n.t("units.#{weight_unit}")) ] if range?(:weight_min, :weight_max)
    pills << [ :water, I18n.t("water.#{water_type}") ] if water_type
    pills << [ :glow, I18n.t("lure.glow") ] if truthy?(:glow)
    pills << [ :uv, I18n.t("lure.uv") ] if truthy?(:uv)
    %i[season clarity water_body wind].each do |k|
      pills << [ k, I18n.t("condition.#{k}.#{@p[k]}", default: @p[k].to_s.titleize) ] if present?(k)
    end
    pills
  end

  def any?
    active_pills.any? || present?(:q)
  end

  private

  def apply_text(scope)
    return scope unless present?(:q)

    q = "%#{@p[:q].to_s.downcase}%"
    scope.joins(:brand).where("LOWER(lures.model) LIKE :q OR LOWER(brands.name) LIKE :q", q: q)
  end

  def apply_catalog(scope)
    scope = scope.joins(:lure_type).where(lure_types: { key: @p[:type] }) if present?(:type)
    scope = scope.joins(:brand).where(brands: { slug: @p[:brand] }) if present?(:brand)
    scope = apply_action(scope) if present?(:lure_action) && Build.actions.key?(@p[:lure_action].to_s)
    scope = apply_depth(scope) if present?(:depth) && DEPTH_BANDS.key?(@p[:depth].to_s)
    scope = apply_water(scope) if water_type
    scope = apply_build_range(scope, :length_mm, :length_min, :length_max)
    scope = apply_build_range(scope, :weight_g, :weight_min, :weight_max, factor: weight_factor)
    scope = apply_finish(scope)
    scope
  end

  # Glow (phosphorescent) and UV (ultraviolet-reactive) are per-color finish
  # flags — a lure matches if any of its colors carries the requested flag. We
  # only ever assert presence, never absence: an untagged lure isn't excluded.
  def apply_finish(scope)
    scope = scope.where(id: Variant.where(glow: true).select(:lure_id)) if truthy?(:glow)
    scope = scope.where(id: Variant.where(uv: true).select(:lure_id)) if truthy?(:uv)
    scope
  end

  # Buoyancy, depth and water now live on builds — a lure matches if any build does.
  def apply_action(scope)
    scope.where(id: Build.where(action: @p[:lure_action]).select(:lure_id))
  end

  # "salt" matches salt + both builds; "fresh" matches fresh + both — a
  # both-water build serves either search.
  def apply_water(scope)
    waters = water_type == "salt" ? [ :salt, :both ] : [ :fresh, :both ]
    scope.where(id: Build.where(water: waters).select(:lure_id))
  end

  # The requested water type, or nil for the unfiltered "any water" default.
  def water_type
    %w[ salt fresh ].include?(@p[:water].to_s) ? @p[:water].to_s : nil
  end

  def apply_depth(scope)
    band_min, band_max = DEPTH_BANDS.fetch(@p[:depth].to_s)
    builds = Build.where("builds.depth_min_cm <= ? AND builds.depth_max_cm >= ?", band_max, band_min)
    scope.where(id: builds.select(:lure_id))
  end

  # Size and weight are per-build specs — a lure matches if any build falls in
  # the range. Builds missing the spec never match a range filter. `factor`
  # converts entered values into the column's canonical unit; converted bounds
  # are rounded to the nearest gram so nominal imperial weights still match
  # their catalog entries (1 oz ≈ 28.35 g must find a "28 g" build).
  def apply_build_range(scope, column, min_key, max_key, factor: 1)
    min, max = numeric(min_key), numeric(max_key)
    return scope unless min || max

    min = (min * factor).round if min && factor != 1
    max = (max * factor).round if max && factor != 1
    range = min ? (max ? min..max : min..) : ..max
    scope.where(id: Build.where(column => range).select(:lure_id))
  end

  # Weights are entered in the unit the search panel advertised (the viewer's
  # preference, carried as weight_unit so shared URLs keep their meaning).
  def weight_unit
    @p[:weight_unit].to_s == "oz" ? "oz" : "g"
  end

  def weight_factor
    weight_unit == "oz" ? Units::G_PER_OZ : 1
  end

  def apply_conditions(scope)
    needs_catches = present?(:species) || %i[season clarity water_body wind].any? { |k| present?(k) }
    return scope unless needs_catches

    scope = scope.joins(variants: :catches)
    scope = scope.where(catches: { species_id: species_id }) if species_id
    %i[season clarity water_body wind].each do |k|
      next unless present?(k)

      enum = Catch.public_send(k.to_s.pluralize)
      scope = scope.where(catches: { k => enum[@p[k].to_s] }) if enum.key?(@p[k].to_s)
    end
    scope
  end

  def apply_sort(scope)
    case @p[:sort].to_s
    when "newest" then scope.order(created_at: :desc)
    when "name" then scope.order(:model)
    when "proven" then scope.by_catch_count
    else scope.order(updated_at: :desc)
    end
  end

  def species_id
    return @species_id if defined?(@species_id)

    @species_id = present?(:species) ? Species.find_by(slug: @p[:species])&.id : nil
  end

  def present?(key)
    @p[key].present?
  end

  def range?(min_key, max_key)
    numeric(min_key) || numeric(max_key)
  end

  def range_label(min_key, max_key, unit)
    min, max = numeric(min_key), numeric(max_key)
    if min && max
      "#{fmt_num(min)}–#{fmt_num(max)} #{unit}"
    elsif min
      "≥ #{fmt_num(min)} #{unit}"
    else
      "≤ #{fmt_num(max)} #{unit}"
    end
  end

  def numeric(key)
    Float(@p[key].to_s)
  rescue ArgumentError
    nil
  end

  def fmt_num(value)
    value == value.to_i ? value.to_i : value
  end

  def truthy?(key)
    %w[1 true on yes].include?(@p[key].to_s)
  end

  def lure_type_label(key)
    I18n.t("lure_type.#{key}", default: key.to_s.titleize)
  end

  def brand_label(slug)
    Brand.find_by(slug: slug)&.name || slug
  end

  def species_label(slug)
    Species.find_by(slug: slug)&.common_name || slug
  end
end
