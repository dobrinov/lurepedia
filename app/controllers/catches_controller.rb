class CatchesController < ApplicationController
  before_action :require_login, only: %i[new create]
  before_action -> { require_contribution(:catches) }, only: %i[new create]

  def index
    @page = paginate(Catch.includes(:user, :species, :build, variant: :lure).recent, per: 12)
    @catches = @page.records
  end

  def show
    @catch = Catch.includes(:user, :species, :comments, :build, variant: :lure).find(params[:id])
    @comments = @catch.comments.includes(:user).chronological
    @related = @catch.species.catches.where.not(id: @catch.id).includes(:user, variant: :lure).recent.limit(4)
  end

  def new
    @species = Species.alpha
    @catch = Catch.new
    load_prefill
  end

  def create
    @catch = Catch.new(catch_params)
    @catch.user = current_user

    if @catch.save
      ModerationItem.create!(subject: @catch, kind: :catch, submitter: current_user)
      redirect_to catch_path(@catch), notice: t("catch.submitted")
    else
      @species = Species.alpha
      load_prefill
      flash.now[:alert] = @catch.errors.full_messages.to_sentence.presence || t("catch.add_title")
      render :new, status: :unprocessable_entity
    end
  end

  private

  # Catch logging can be launched from many places (lure page, species page, …);
  # each may seed the brand → lure → color → build cascade via query params. On a
  # failed create we re-derive the same selections from the submitted catch so the
  # form comes back filled in. All prefills stay editable on the form.
  def load_prefill
    @selected_lure = Lure.find_by(slug: params[:lure]) || @catch.variant&.lure
    @selected_brand = Brand.find_by(slug: params[:brand]) || @selected_lure&.brand
    @selected_variant = @catch.variant || @selected_lure&.variants&.find_by(id: params[:variant_id])
    @selected_build = @catch.build || @selected_lure&.builds&.find_by(id: params[:build_id])
    @selected_species = @catch.species || (Species.find_by(slug: params[:species]) if params[:species].present?)
  end

  def catch_params
    params.require(:catch).permit(
      :variant_id, :build_id, :species_id, :season, :clarity, :water_body, :wind, :time_of_day, :platform, :retrieve,
      :location, :note, :length_cm, :weight_g, photos: []
    )
  end
end
