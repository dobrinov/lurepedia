class SitemapsController < ApplicationController
  def index
    @locales = I18n.available_locales
    @static_paths = %i[lures species_index brands shops catches leaderboard]
    @lures = Lure.published
    @species = Species.published
    @brands = Brand.published
    @shops = Shop.published
    @catch_records = Catch.all
    respond_to { |format| format.xml }
  end
end
