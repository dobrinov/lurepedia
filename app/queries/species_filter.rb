# Filters the species dictionary by name (locale-aware), water, hazards and proof.
class SpeciesFilter < CatalogFilter
  ATTRS = %i[q water venomous poisonous proven].freeze

  # Name search happens in Ruby over the full, bounded species set (see
  # Species#name_matches?), so results is an Array when a query is present —
  # Paginatable accepts both.
  def results
    scope = Species.alpha.published
    scope = scope.where(water: water_values) if water?
    scope = scope.where(venomous: true) if truthy?(:venomous)
    scope = scope.where(poisonous: true) if truthy?(:poisonous)
    scope = scope.proven if truthy?(:proven)
    return scope unless present?(:q)

    scope.to_a.select { |s| s.name_matches?(query) }
  end

  # Active filters as [key, label] for rendering removable pills.
  def active_pills
    pills = []
    pills << [ :water, I18n.t("water.#{@p[:water]}") ] if water?
    pills << [ :venomous, I18n.t("species.venomous") ] if truthy?(:venomous)
    pills << [ :poisonous, I18n.t("species.poisonous") ] if truthy?(:poisonous)
    pills << [ :proven, I18n.t("search.proven_only") ] if truthy?(:proven)
    pills
  end

  private

  def water?
    present?(:water) && Species.waters.key?(@p[:water].to_s)
  end

  # Fresh or salt include species living in both, matching the lure search's
  # saltwater semantics; picking "both" narrows to true fresh-and-salt species.
  def water_values
    value = @p[:water].to_s
    value == "both" ? [ :both ] : [ value.to_sym, :both ]
  end
end
