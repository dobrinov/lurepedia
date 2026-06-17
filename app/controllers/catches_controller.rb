class CatchesController < ApplicationController
  before_action :require_login, only: %i[new create]
  before_action -> { require_contribution(:catches) }, only: %i[new create]

  def index
    @page = paginate(Catch.includes(:user, :species, variant: :lure).recent, per: 12)
    @catches = @page.records
  end

  def show
    @catch = Catch.includes(:user, :species, :comments, variant: :lure).find(params[:id])
    @comments = @catch.comments.includes(:user).chronological
    @related = @catch.species.catches.where.not(id: @catch.id).includes(:user, variant: :lure).recent.limit(4)
  end

  def new
    @lures = Lure.includes(:brand).by_catch_count
    @species = Species.alpha
    @selected_lure = Lure.find_by(slug: params[:lure])
    @catch = Catch.new
  end

  def create
    @catch = Catch.new(catch_params)
    @catch.user = current_user

    if @catch.save
      ModerationItem.create!(subject: @catch, kind: :catch, submitter: current_user)
      redirect_to catch_path(@catch), notice: t("catch.submitted")
    else
      @lures = Lure.includes(:brand).by_catch_count
      @species = Species.alpha
      flash.now[:alert] = @catch.errors.full_messages.to_sentence.presence || t("catch.add_title")
      render :new, status: :unprocessable_entity
    end
  end

  private

  def catch_params
    params.require(:catch).permit(
      :variant_id, :species_id, :season, :clarity, :water_body, :wind, :time_of_day,
      :location, :note, :length_cm, :weight_g, photos: []
    )
  end
end
