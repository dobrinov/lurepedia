# Shared plumbing for the directory filters (brands, species, shops): param
# normalization, pill clearing and predicate helpers. Subclasses implement
# #results and #active_pills, mirroring LureFilter's interface.
class CatalogFilter
  def self.pill_params(key)
    [ key.to_s ]
  end

  def initialize(params = {})
    @p = params.respond_to?(:to_unsafe_h) ? params.to_unsafe_h.symbolize_keys : params.symbolize_keys
  end

  def any?
    active_pills.any? || present?(:q)
  end

  private

  def query
    @p[:q].to_s.strip
  end

  def present?(key)
    @p[key].present?
  end

  def truthy?(key)
    %w[1 true on yes].include?(@p[key].to_s)
  end

  def country_label(code)
    ApplicationController.helpers.country_name(code)
  end
end
