class ShopsController < ApplicationController
  before_action :require_login, only: %i[new create]

  def index
    @promoted = Shop.promoted.order(:name)
    @page = paginate(Shop.regular.order(:name), per: 9)
    @shops = @page.records
  end

  def new
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
    params.require(:shop).permit(:name, :url, :blurb)
  end
end
