module SearchFiltersHelper
  # Small, static filter dropdowns rendered with the inline (client-side) combobox,
  # in display order.
  STATIC_FILTERS = %i[type season water_body clarity wind lure_action depth].freeze

  def static_filter_fields
    STATIC_FILTERS.index_with do |field|
      {
        label: filter_label(field),
        placeholder: filter_placeholder(field),
        options: static_filter_options(field)
      }
    end
  end

  def selected_species_label(slug)
    Species.find_by(slug: slug)&.common_name if slug.present?
  end

  def selected_brand_label(slug)
    Brand.find_by(slug: slug)&.name if slug.present?
  end

  private

  def static_filter_options(field)
    case field
    when :type
      LureType.all.sort_by(&:key).map { |lt| [ lure_type_name(lt), lt.key ] }
    when :lure_action
      Lure.actions.keys.excluding("none").map { |k| [ lure_action_label(k), k ] }
    when :depth
      LureFilter::DEPTH_BANDS.keys.map { |k| [ t("search.depth_band.#{k}", default: k.titleize), k ] }
    else # season, water_body, clarity, wind
      Catch.public_send(field.to_s.pluralize).keys.map { |k| [ condition_name(field, k), k ] }
    end
  end

  def filter_label(field)
    case field
    when :type then t("lure.type")
    when :lure_action then t("lure.action")
    when :depth then t("lure.depth")
    else t("search.#{field}", default: field.to_s.humanize) # season, water_body, clarity, wind
    end
  end

  def filter_placeholder(field)
    case field
    when :type then t("search.any_type")
    when :depth then t("search.any_depth")
    when :lure_action then t("search.any_action", default: t("search.any_type"))
    else t("condition.#{field}.any")
    end
  end
end
