class LuresController < ApplicationController
  before_action :require_login, only: %i[new create edit update]
  before_action :load_form_collections, only: %i[new create edit update]

  def index
    @filter = LureFilter.new(params)
    @lure_types = LureType.all
    @page = paginate(@filter.results, per: 12)
    @lures = @page.records
  end

  def show
    @lure = Lure.includes(:brand, :lure_type, variants: { photo_attachment: :blob }).find_by!(slug: params[:id])
    @variants = @lure.variants
    @catches = @lure.catches.includes(:user, :species).recent.limit(8)
    @proven_species = @lure.proven_species
    @buy_links = @lure.buy_links.includes(:shop).sort_by { |b| b.shop.promoted? ? 0 : 1 }
  end

  def new
    @lure = Lure.new
  end

  def create
    brand = Brand.find_by(id: params.dig(:lure, :brand_id))
    type = LureType.find_by(id: params.dig(:lure, :lure_type_id)) || LureType.first
    @lure = Lure.new(lure_params.merge(brand: brand, lure_type: type))

    if brand && @lure.save
      @lure.revisions.create!(user: current_user, summary: t("provenance.created"))
      ModerationItem.create!(subject: @lure, kind: :catalog, submitter: current_user)
      redirect_to lure_path(@lure), notice: t("catch.submitted")
    else
      flash.now[:alert] = @lure.errors.full_messages.to_sentence.presence || t("brand.title")
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @lure = Lure.find_by!(slug: params[:id])
  end

  def update
    @lure = Lure.find_by!(slug: params[:id])
    attrs = lure_params
    attrs[:brand_id] = params.dig(:lure, :brand_id) if params.dig(:lure, :brand_id).present?
    attrs[:lure_type_id] = params.dig(:lure, :lure_type_id) if params.dig(:lure, :lure_type_id).present?
    commit_edit(@lure, attrs, @lure.title, lure_path(@lure))
  end

  private

  def load_form_collections
    @brands = Brand.alpha
    @lure_types = LureType.all
  end

  def lure_params
    params.require(:lure).permit(:model, :water, :action, :depth_min_cm, :depth_max_cm, :blurb, :action_video_url)
  end
end
