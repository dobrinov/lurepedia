class ProfilesController < ApplicationController
  def show
    @user = User.find_by_handle!(params[:handle])
    @owner = current_user == @user
    @catches = @user.catches.includes(:species, variant: :lure).recent
    @total_upvotes = @catches.sum(&:upvotes_count)
    @favorite_species = favorites_of("Species")
    @favorite_lures = favorites_of("Lure")
    @favorite_shops = favorites_of("Shop")
  end

  private

  # Resolved favoritable records of one type, newest first.
  # Favorites are few per user, so per-record loading is acceptable here and
  # matches the app's existing simple query patterns.
  def favorites_of(type)
    @user.favorites.where(favoritable_type: type).order(created_at: :desc).map(&:favoritable).compact
  end
end
