# Filters lures by catalog attributes and (via catches) condition attributes.
class LureFilter
  ATTRS = %i[q type brand species lure_action depth water_body season clarity wind saltwater sort].freeze

  # Depth bands in centimetres, matched by overlap against a lure's [min, max] range.
  DEPTH_BANDS = { "shallow" => [ 0, 150 ], "mid" => [ 150, 450 ], "deep" => [ 450, 100_000 ] }.freeze

  def initialize(params = {})
    @p = params.respond_to?(:to_unsafe_h) ? params.to_unsafe_h.symbolize_keys : params.symbolize_keys
  end

  def results
    scope = Lure.includes(:brand, :lure_type).all
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
    pills << [ :saltwater, I18n.t("search.saltwater_only") ] if truthy?(:saltwater)
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
    scope = scope.where(action: @p[:lure_action]) if present?(:lure_action) && Lure.actions.key?(@p[:lure_action].to_s)
    scope = apply_depth(scope) if present?(:depth) && DEPTH_BANDS.key?(@p[:depth].to_s)
    scope = scope.where(water: :salt) if truthy?(:saltwater)
    scope
  end

  def apply_depth(scope)
    band_min, band_max = DEPTH_BANDS.fetch(@p[:depth].to_s)
    scope.where("lures.depth_min_cm <= ? AND lures.depth_max_cm >= ?", band_max, band_min)
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
    else scope.by_catch_count
    end
  end

  def species_id
    return @species_id if defined?(@species_id)

    @species_id = present?(:species) ? Species.find_by(slug: @p[:species])&.id : nil
  end

  def present?(key)
    @p[key].present?
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
