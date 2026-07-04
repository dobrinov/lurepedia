class ShopsController < ApplicationController
  before_action :require_login, only: %i[new create edit update]
  before_action -> { require_contribution(:catalog) }, only: %i[new create edit update]

  def index
    @q = params[:q].to_s.strip
    shops = Shop.published.includes(:claim).promoted_first
    shops = shops.where("LOWER(name) LIKE ?", "%#{@q.downcase}%") if @q.present?
    @country = helpers.viewer_country
    local, other = shops.partition { |shop| shop.ships_to_country?(@country) }
    @local_shops = local
    @page = paginate(other, per: 9)
    @other_shops = @page.records
  end

  def show
    @shop = Shop.find_by!(slug: params[:id])
    raise ActiveRecord::RecordNotFound unless @shop.visible_to?(current_user)

    @lures = @shop.lures.published.includes(:lure_type).by_catch_count
    @tab = %w[lures history].include?(params[:tab]) ? params[:tab] : "lures"
  end

  def new
    @shop = Shop.new
  end

  def create
    @shop = Shop.new(shop_params)

    if @shop.save
      @shop.revisions.create!(user: current_user, summary: t("provenance.created"))
      if can_add_directly?(owning_brand(@shop))
        redirect_to shops_path, notice: t("contribute.added")
      else
        ModerationItem.create!(subject: @shop, kind: :catalog, submitter: current_user)
        redirect_to shops_path, notice: t("catch.submitted")
      end
    else
      flash.now[:alert] = @shop.errors.full_messages.to_sentence
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @shop = Shop.find_by!(slug: params[:id])
  end

  def update
    @shop = Shop.find_by!(slug: params[:id])
    commit_edit(@shop, shop_params, @shop.name, shop_path(@shop))
  end

  private

  def shop_params
    params.require(:shop).permit(:name, :url, :blurb, :ships_to, :ships_worldwide)
  end
end
