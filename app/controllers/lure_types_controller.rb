# Indexable hub pages, one per lure type. The same listing already exists as a
# filter (/lures?type=jerkbait), but filtered URLs self-canonicalize to /lures
# and so are invisible to search. These are real pages: they answer the queries
# people actually type ("jerkbait", "topwater lures") and they give crawlers a
# shallow path into a catalog whose paginated index runs ~170 pages deep.
#
# Read-only and public — types are a fixed taxonomy, not contributed content,
# so there is nothing here to gate on login or moderation.
class LureTypesController < ApplicationController
  def index
    # Sorted on the I18n-resolved name, so the list reads alphabetically in
    # whatever locale the visitor is browsing.
    @lure_types = LureType.all.to_a.sort_by(&:name)
    @counts = Lure.published.group(:lure_type_id).count
  end

  def show
    @lure_type = LureType.find_by!(key: params[:id])
    lures = Lure.published.where(lure_type: @lure_type).includes(:brand, :lure_type).by_catch_count
    @page = paginate(lures, per: 12)
    @lures = @page.records
  end
end
