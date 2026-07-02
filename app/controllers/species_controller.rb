class SpeciesController < ApplicationController
  before_action :require_login, only: %i[new create edit update]
  before_action -> { require_contribution(:catalog) }, only: %i[new create edit update]

  def index
    @q = params[:q].to_s.strip
    scope = Species.alpha.published
    if @q.present?
      # Ruby-side over the full, bounded species set — same approach as
      # FilterOptionsController#species.
      scope = scope.to_a.select { |s| s.name_matches?(@q) }
    end
    @page = paginate(scope, per: 12)
    @species = @page.records
    @proven_lure_counts = Species.proven_lure_counts(@species)
  end

  def show
    @species = Species.find_by!(slug: params[:id])
    raise ActiveRecord::RecordNotFound unless @species.visible_to?(current_user)

    @lures = @species.proven_lures.published.includes(:brand, :lure_type)
    @catches = @species.catches.includes(:user, variant: :lure).recent.limit(12)
    @metric = (params[:metric] || "length").to_sym
    @rows = LeaderboardQuery.new(species: @species, metric: @metric).rows
    @tab = %w[lures catches leaderboard history].include?(params[:tab]) ? params[:tab] : "lures"
  end

  def new
    @species = Species.new
  end

  def create
    @species = Species.new(species_params)
    @species.key = @species.scientific_name.to_s.parameterize(separator: "_").presence || "species_#{SecureRandom.hex(3)}"

    if @species.save
      @species.revisions.create!(user: current_user, summary: t("provenance.created"))
      if can_add_directly?(owning_brand(@species))
        redirect_to species_path(@species), notice: t("contribute.added")
      else
        ModerationItem.create!(subject: @species, kind: :catalog, submitter: current_user)
        redirect_to species_path(@species), notice: t("catch.submitted")
      end
    else
      flash.now[:alert] = @species.errors.full_messages.to_sentence
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @species = Species.find_by!(slug: params[:id])
  end

  def update
    @species = Species.find_by!(slug: params[:id])
    commit_edit(@species, species_params, @species.common_name, species_path(@species))
  end

  private

  def species_params
    params.require(:species).permit(:scientific_name, :water, :wikipedia_url, :photo, local_names: I18n.available_locales.map(&:to_s))
  end
end
