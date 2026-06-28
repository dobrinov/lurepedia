class BrandsController < ApplicationController
  before_action :require_login, only: %i[new create edit update]
  before_action -> { require_contribution(:catalog) }, only: %i[new create edit update]

  def index
    @page = paginate(Brand.alpha.published.includes(:claim), per: 12)
    @brands = @page.records
  end

  def show
    @brand = Brand.find_by!(slug: params[:id])
    raise ActiveRecord::RecordNotFound unless @brand.visible_to?(current_user)

    @lures = @brand.lures.published.includes(:lure_type).by_catch_count
    @tab = %w[lures history].include?(params[:tab]) ? params[:tab] : "lures"
  end

  def new
    @brand = Brand.new
  end

  def create
    @brand = Brand.new(brand_params)

    if @brand.save
      @brand.revisions.create!(user: current_user, summary: t("provenance.created"))
      if can_add_directly?(@brand)
        redirect_to brand_path(@brand), notice: t("contribute.added")
      else
        ModerationItem.create!(subject: @brand, kind: :catalog, submitter: current_user)
        redirect_to brand_path(@brand), notice: t("catch.submitted")
      end
    else
      flash.now[:alert] = @brand.errors.full_messages.to_sentence
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @brand = Brand.find_by!(slug: params[:id])
  end

  def update
    @brand = Brand.find_by!(slug: params[:id])
    commit_edit(@brand, brand_params, @brand.name, brand_path(@brand))
  end

  private

  def brand_params
    params.require(:brand).permit(:name, :country, :founded_year, :blurb, :website, :logo)
  end
end
