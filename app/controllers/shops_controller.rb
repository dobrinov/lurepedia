class ShopsController < ApplicationController
  before_action :require_login, only: %i[new create]
  before_action -> { require_contribution(:catalog) }, only: %i[new create]

  def index
    @promoted = Shop.promoted.includes(:claim).order(:name)
    @page = paginate(Shop.regular.includes(:claim).order(:name), per: 9)
    @shops = @page.records
  end

  def show
    @shop = Shop.find_by!(slug: params[:id])
    @lures = @shop.lures.includes(:lure_type).by_catch_count
    @tab = %w[lures history].include?(params[:tab]) ? params[:tab] : "lures"
  end

  def new
    @shop = Shop.new
  end

  def create
    @shop = Shop.new(shop_params)

    if @shop.save
      @shop.revisions.create!(user: current_user, summary: t("provenance.created"))
      ModerationItem.create!(subject: @shop, kind: :catalog, submitter: current_user)
      redirect_to shops_path, notice: t("catch.submitted")
    else
      flash.now[:alert] = @shop.errors.full_messages.to_sentence
      render :new, status: :unprocessable_entity
    end
  end

  private

  def shop_params
    params.require(:shop).permit(:name, :url, :blurb, :ships_to, :ships_worldwide)
  end
end
