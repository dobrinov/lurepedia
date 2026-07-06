# Filters the shop directory by name, delivery country and ownership.
class ShopFilter < CatalogFilter
  ATTRS = %i[q country worldwide claimed].freeze

  # Delivery-country filtering happens in Ruby: ships_to is a comma-separated
  # code list plus a worldwide flag (see Shop#ships_to_country?), so results
  # is an Array when a country is chosen — Paginatable accepts both.
  def results
    scope = Shop.published.includes(:claim).promoted_first
    scope = scope.where("LOWER(shops.name) LIKE ?", "%#{query.downcase}%") if present?(:q)
    scope = scope.where(ships_worldwide: true) if truthy?(:worldwide)
    scope = scope.joins(:claim).where(claims: { status: :verified }) if truthy?(:claimed)
    return scope unless present?(:country)

    scope.to_a.select { |shop| shop.ships_to_country?(@p[:country]) }
  end

  # Active filters as [key, label] for rendering removable pills.
  def active_pills
    pills = []
    pills << [ :country, country_label(@p[:country]) ] if present?(:country)
    pills << [ :worldwide, I18n.t("shop.ships_worldwide") ] if truthy?(:worldwide)
    pills << [ :claimed, I18n.t("claim.managed_badge") ] if truthy?(:claimed)
    pills
  end
end
