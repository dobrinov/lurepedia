# Serves paginated, searchable option lists for the large filter dropdowns
# (species, brands), consumed by the async_combobox Stimulus controller.
class FilterOptionsController < ApplicationController
  PER = 20

  # Species display names are I18n-derived from `key` (no name column), so search
  # and pagination happen in Ruby over the full, bounded species set. Brands are
  # paginated at the database level since they can grow large.
  def species
    records = Species.alpha.published.to_a
    records = records.select { |s| s.common_name.downcase.include?(query) } if query.present?
    render_page(records[offset, PER + 1] || []) { |s| { value: s.slug, label: s.common_name } }
  end

  def brands
    scope = Brand.alpha.published
    scope = scope.where("LOWER(name) LIKE ?", "%#{query}%") if query.present?
    render_page(scope.offset(offset).limit(PER + 1).to_a) { |b| { value: b.slug, label: b.name } }
  end

  def lures
    scope = Lure.published.includes(:brand).by_catch_count
    scope = scope.joins(:brand) if params[:brand].present? || query.present?
    scope = scope.where(brands: { slug: params[:brand] }) if params[:brand].present?
    if query.present?
      scope = scope.where("LOWER(lures.model) LIKE :q OR LOWER(brands.name) LIKE :q", q: "%#{query}%")
    end
    render_page(scope.offset(offset).limit(PER + 1).to_a) { |l| { value: l.slug, label: l.title } }
  end

  def shops
    scope = Shop.promoted_first.published
    scope = scope.where("LOWER(name) LIKE ?", "%#{query}%") if query.present?
    render_page(scope.offset(offset).limit(PER + 1).to_a) { |s| { value: s.slug, label: s.name } }
  end

  private

  def query
    @query ||= params[:q].to_s.strip.downcase
  end

  def page
    [ params[:page].to_i, 1 ].max
  end

  def offset
    (page - 1) * PER
  end

  # `slice` holds up to PER+1 records; the extra one tells us whether more exist.
  def render_page(slice)
    has_more = slice.size > PER
    results = slice.first(PER).map { |record| yield(record) }
    render json: { results: results, next_page: has_more ? page + 1 : nil }
  end
end
