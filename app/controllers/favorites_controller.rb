class FavoritesController < ApplicationController
  before_action :require_login
  before_action -> { require_contribution(:favorites) }
  before_action :set_favoritable

  def create
    Favorite.find_or_create_by!(user: current_user, favoritable: @favoritable)
    redirect_back fallback_location: favoritable_path
  end

  def destroy
    Favorite.where(user: current_user, favoritable: @favoritable).destroy_all
    redirect_back fallback_location: favoritable_path
  end

  private

  def set_favoritable
    klass = { "Species" => Species, "Lure" => Lure, "Shop" => Shop }[params[:favoritable_type].to_s]
    return head :unprocessable_entity unless klass

    @favoritable = klass.find(params[:favoritable_id])
  end

  # Fallback is only used when there's no referer. Shops have no show route,
  # so polymorphic_path can raise; fall back to root_path in that case.
  def favoritable_path
    polymorphic_path(@favoritable)
  rescue NoMethodError, ActionController::UrlGenerationError
    root_path
  end
end
