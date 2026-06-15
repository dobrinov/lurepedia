class SitemapsController < ApplicationController
  def index
    @locales = I18n.available_locales
    @static_paths = %i[lures species_index brands shops catches leaderboard]
    @lures = Lure.all
    @species = Species.all
    @brands = Brand.all
    respond_to { |format| format.xml }
  end
end
