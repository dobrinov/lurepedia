class ApplicationController < ActionController::Base
  include Authentication
  include Authorization
  include Paginatable
  include Editable

  # Public browsing is the default; gate specific actions with require_login etc.

  allow_browser versions: :modern
  stale_when_importmap_changes

  around_action :switch_locale

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

  def default_url_options
    { locale: I18n.locale }
  end
end
