class LeaderboardController < ApplicationController
  def index
    @metric = (params[:metric] || "catches").to_sym
    @selected_species = Species.find_by(slug: params[:species])
    @species_options = Species.proven.alpha
    @rows = LeaderboardQuery.new(species: @selected_species, metric: @metric).rows
  end
end
