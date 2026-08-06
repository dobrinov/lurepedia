class SitemapsController < ApplicationController
  # /sitemap.xml — a sitemap index pointing at one sitemap per indexable locale.
  def index
    @locales = Locales.indexable
    @lastmod = last_modified
    respond_to { |format| format.xml }
  end

  # /sitemaps/:locale.xml — every page in a single locale, each <url> carrying
  # the hreflang alternate set so crawlers discover the other published languages.
  # Non-indexable locales 404 rather than serve: those pages are noindex, and a
  # 404 also drops any copy still submitted in Search Console.
  def show
    @locale = params[:locale].to_sym
    return head :not_found unless Locales.indexable?(@locale)

    @locales = Locales.indexable
    @static_paths = %i[lures species_index brands shops catches leaderboard]
    @lures = Lure.published
    @species = Species.published
    @brands = Brand.published
    @shops = Shop.published
    @catch_records = Catch.all
    respond_to { |format| format.xml }
  end

  private

    def last_modified
      [ Lure.published.maximum(:updated_at),
        Species.published.maximum(:updated_at),
        Brand.published.maximum(:updated_at),
        Shop.published.maximum(:updated_at),
        Catch.maximum(:updated_at) ].compact.max
    end
end
