class ProfilesController < ApplicationController
  TABS = %w[catches favorites contributions].freeze
  OWNER_TABS = %w[settings].freeze

  def show
    @user = User.find_by_handle!(params[:handle])
    @owner = current_user == @user
    @tab = resolve_tab(params[:tab])

    @catches = @user.catches.includes(:species, variant: :lure).recent
    @total_upvotes = @catches.sum(&:upvotes_count)
    @contributions_count = @user.revisions.count

    case @tab
    when "favorites"
      @favorite_species = favorites_of("Species")
      @favorite_lures = favorites_of("Lure")
      @favorite_shops = favorites_of("Shop")
    when "contributions"
      @contributions = @user.revisions.includes(:subject).newest_first
    end
  end

  private

  # Settings/preferences tabs are owner-only; everything else is public.
  # Unknown or disallowed tabs fall back to the default.
  def resolve_tab(tab)
    return tab if TABS.include?(tab)
    return tab if OWNER_TABS.include?(tab) && @owner

    "catches"
  end

  # Resolved favoritable records of one type, newest first.
  # Favorites are few per user, so per-record loading is acceptable here and
  # matches the app's existing simple query patterns.
  def favorites_of(type)
    @user.favorites.where(favoritable_type: type).order(created_at: :desc).map(&:favoritable).compact
  end
end
