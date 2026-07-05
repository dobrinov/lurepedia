class ApplicationController < ActionController::Base
  include Authentication
  include Authorization
  include Paginatable
  include Editable

  # Public browsing is the default; gate specific actions with require_login etc.

  allow_browser versions: :modern
  stale_when_importmap_changes

  around_action :switch_locale
  around_action :use_time_zone
  before_action :canonicalize_root_locale
  before_action :noindex_form_pages

  helper_method :current_user, :signed_in?

  private

  def current_user
    Current.user
  end

  def signed_in?
    current_user.present?
  end

  # Narrows a catalog scope (variants, builds, …) to what the viewer may see:
  # moderators see everything for review, everyone else sees only published
  # entries. Pending entries stay reachable to their submitter via the edit
  # screens they're redirected to on creation.
  def visible_catalog(scope)
    current_user&.can_moderate? ? scope : scope.published
  end

  # Form screens are contributor UI, not search content; SeoHelper's
  # robots_meta_tag renders the noindex meta from @noindex.
  def noindex_form_pages
    @noindex = true if %w[new edit].include?(action_name)
  end

  def switch_locale(&action)
    locale = params[:locale]
    locale = nil unless I18n.available_locales.map(&:to_s).include?(locale)
    locale ||= current_user&.locale
    locale ||= cookies[:locale]
    locale = I18n.default_locale unless I18n.available_locales.map(&:to_s).include?(locale.to_s)
    I18n.with_locale(locale, &action)
  end

  # Render timestamps in the signed-in user's preferred zone. Active Record's
  # time-zone-aware attributes are read in Time.zone, so wrapping the request
  # makes every `created_at` etc. localize without per-view conversion. Falls
  # back to the app default zone for guests or an unset/invalid preference.
  def use_time_zone(&action)
    zone = current_user&.time_zone
    zone = nil unless zone.present? && ActiveSupport::TimeZone[zone]
    zone ? Time.use_zone(zone, &action) : action.call
  end

  # Anonymous visitors get canonical, locale-prefixed URLs, so a bare "/" is
  # redirected to the localized home. Signed-in users keep locale-free URLs and
  # are served at "/" directly. Runs inside switch_locale, so I18n.locale is set.
  def canonicalize_root_locale
    return if signed_in? || params[:locale].present?
    return unless (request.get? || request.head?) && request.path == "/"

    redirect_to localized_root_path(locale: I18n.locale), status: :moved_permanently
  end

  def default_url_options
    # Signed-in users get clean, locale-free URLs (their locale comes from their
    # account preference); anonymous visitors keep the locale in the path.
    # `locale: nil` omits the optional segment while still claiming it, so
    # positional path args (e.g. profile_path(user)) fill the right segment.
    return { locale: nil } if signed_in?

    { locale: I18n.locale }
  end
end
