class BuyLinksController < ApplicationController
  include Editable

  before_action :require_login
  before_action -> { require_contribution(:catalog) }

  # Adds a "where to buy" link straight from the lure page. The shop is either
  # an existing one (picked from the combobox) or created inline. Like other
  # catalog contributions everything is created live; non-admins also get a
  # moderation item so the addition can be reviewed.
  def create
    @lure = Lure.find_by!(slug: params[:lure_id])
    shop = params[:shop_source] == "new" ? build_new_shop : Shop.find_by(slug: params[:shop])

    return redirect_back_with(alert: t("buy_link.shop_required")) unless shop
    return redirect_back_with(alert: shop.errors.full_messages.to_sentence) if shop.errors.any?

    link = @lure.buy_links.find_or_initialize_by(shop: shop)
    return redirect_back_with(alert: t("buy_link.already_listed")) if link.persisted?

    link.url = params[:url].to_s.strip.presence
    link.save!
    direct = can_add_directly?(@lure.brand)
    ModerationItem.create!(subject: link, kind: :catalog, submitter: current_user) unless direct

    redirect_back_with(notice: direct ? t("contribute.added") : t("catch.submitted"))
  end

  private

  # Creates a shop the same way ShopsController#create does (live + a revision +
  # a review item), or returns the unsaved record carrying its validation errors.
  def build_new_shop
    shop = Shop.new(new_shop_params)
    return shop unless shop.save

    shop.revisions.create!(user: current_user, summary: t("provenance.created"))
    ModerationItem.create!(subject: shop, kind: :catalog, submitter: current_user)
    shop
  end

  def new_shop_params
    (params[:new_shop] || ActionController::Parameters.new).permit(:name, :url, :ships_to, :ships_worldwide)
  end

  def redirect_back_with(**flash)
    redirect_to lure_path(@lure, tab: "buy"), **flash
  end
end
