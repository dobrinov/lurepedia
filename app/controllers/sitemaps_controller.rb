class SitemapsController < ApplicationController
  # /sitemap.xml — a sitemap index pointing at one sitemap per locale.
  def index
    @locales = I18n.available_locales
    @lastmod = last_modified
    respond_to { |format| format.xml }
  end

  # /sitemaps/:locale.xml — every page in a single locale, each <url> carrying
  # the full hreflang alternate set so crawlers still discover the other languages.
  def show
    @locale = params[:locale].to_sym
    @locales = I18n.available_locales
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
