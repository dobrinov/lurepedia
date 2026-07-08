module SearchFiltersHelper
  # Small, static filter dropdowns rendered with the inline (client-side) combobox,
  # in display order.
  STATIC_FILTERS = %i[type season water_body clarity wind lure_action depth water].freeze

  def static_filter_fields
    STATIC_FILTERS.index_with do |field|
      {
        label: filter_label(field),
        placeholder: filter_placeholder(field),
        options: static_filter_options(field)
      }
    end
  end

  # A query param read as a scalar filter value. Guards against the param name
  # colliding with a nested form body (e.g. brands#create posts brand[...] as a
  # hash), which the global search bar would otherwise try to cast to a slug.
  def selected_filter_value(key)
    value = params[key]
    value if value.is_a?(String) && value.present?
  end

  def selected_species_label(slug)
    Species.find_by(slug: slug)&.common_name if slug.is_a?(String) && slug.present?
  end

  def selected_brand_label(slug)
    Brand.find_by(slug: slug)&.name if slug.is_a?(String) && slug.present?
  end

  # Unit for the weight range inputs: whatever unit the values in the URL were
  # typed in, else the viewer's preference for a fresh search.
  def selected_weight_filter_unit
    param = selected_filter_value(:weight_unit)
    %w[ g oz ].include?(param) ? param : viewer_weight_unit
  end

  # Origin countries actually present in the brand directory, as combobox options.
  def brand_country_options
    Brand.published.where.not(country: [ nil, "" ]).distinct.pluck(:country)
         .map { |code| [ country_name(code), code ] }.sort_by(&:first)
  end

  def species_water_options
    Species.waters.keys.map { |key| [ water_name(key), key ] }
  end

  private

  def static_filter_options(field)
    case field
    when :type
      LureType.all.sort_by(&:key).map { |lt| [ lure_type_name(lt), lt.key ] }
    when :lure_action
      Build.actions.keys.excluding("none").map { |k| [ lure_action_label(k), k ] }
    when :depth
      LureFilter::DEPTH_BANDS.keys.map { |k| [ t("search.depth_band.#{k}", default: k.titleize), k ] }
    when :water
      %w[ salt fresh ].map { |k| [ water_name(k), k ] }
    else # season, water_body, clarity, wind
      Catch.public_send(field.to_s.pluralize).keys.map { |k| [ condition_name(field, k), k ] }
    end
  end

  def filter_label(field)
    case field
    when :type then t("lure.type")
    when :lure_action then t("lure.buoyancy")
    when :depth then t("lure.depth")
    when :water then t("lure.water")
    else t("condition.#{field}.label", default: field.to_s.humanize) # season, water_body, clarity, wind
    end
  end

  def filter_placeholder(field)
    case field
    when :type then t("search.any_type")
    when :depth then t("search.any_depth")
    when :lure_action then t("search.any_action", default: t("search.any_type"))
    when :water then t("search.any_water")
    else t("condition.#{field}.any")
    end
  end
end
