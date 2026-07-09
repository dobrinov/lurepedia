module TaxonomyHelper
  def species_common_name(species)
    key = species.respond_to?(:key) ? species.key : species
    t("species_names.#{key}.common", default: key.to_s.titleize)
  end

  def species_habitat(species)
    key = species.respond_to?(:key) ? species.key : species
    t("species_names.#{key}.habitat", default: "")
  end

  def lure_type_name(type)
    key = type.respond_to?(:key) ? type.key : type
    t("lure_type.#{key}", default: key.to_s.titleize)
  end

  def water_name(water)
    t("water.#{water}", default: water.to_s.titleize)
  end

  def material_name(material)
    t("material.#{material}", default: material.to_s.titleize)
  end

  def lure_action_label(action)
    return t("action.none") if action.blank? || action.to_s == "none"

    t("action.#{action}", default: action.to_s.titleize)
  end

  def condition_name(group, value)
    return "" if value.blank?

    t("condition.#{group}.#{value}", default: value.to_s.titleize)
  end
end
