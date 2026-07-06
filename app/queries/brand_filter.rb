# Filters the brand directory by name, origin country, ownership and proof.
class BrandFilter < CatalogFilter
  ATTRS = %i[q country claimed proven].freeze

  def results
    scope = Brand.alpha.published.includes(:claim)
    scope = scope.where("LOWER(brands.name) LIKE ?", "%#{query.downcase}%") if present?(:q)
    scope = scope.where(country: @p[:country].to_s.upcase) if present?(:country)
    scope = scope.joins(:claim).where(claims: { status: :verified }) if truthy?(:claimed)
    scope = scope.where(id: Lure.where("catches_count > 0").select(:brand_id)) if truthy?(:proven)
    scope
  end

  # Active filters as [key, label] for rendering removable pills.
  def active_pills
    pills = []
    pills << [ :country, country_label(@p[:country]) ] if present?(:country)
    pills << [ :claimed, I18n.t("claim.managed_badge") ] if truthy?(:claimed)
    pills << [ :proven, I18n.t("search.proven_only") ] if truthy?(:proven)
    pills
  end
end
