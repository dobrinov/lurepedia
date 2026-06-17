class ApplicationController < ActionController::Base
  include Authentication
  include Authorization
  include Paginatable
  include Editable

  # Public browsing is the default; gate specific actions with require_login etc.

  allow_browser versions: :modern
  stale_when_importmap_changes

  around_action :switch_locale
  before_action :canonicalize_root_locale

  helper_method :current_user, :signed_in?

  private

  def current_user
    Current.user
  end

  def signed_in?
    current_user.present?
  end

  def switch_locale(&action)
    locale = params[:locale]
    locale = nil unless I18n.available_locales.map(&:to_s).include?(locale)
    locale ||= current_user&.locale
    locale ||= cookies[:locale]
    locale = I18n.default_locale unless I18n.available_locales.map(&:to_s).include?(locale.to_s)
    I18n.with_locale(locale, &action)
  end

  # Anonymous visitors get canonical, locale-prefixed URLs, so a bare "/" is
  # redirected to the localized home. Signed-in users keep locale-free URLs and
  # are served at "/" directly. Runs inside switch_locale, so I18n.locale is set.
  def canonicalize_root_locale
    return if signed_in? || params[:locale].present?
    return unless request.get? && request.path == "/"

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
