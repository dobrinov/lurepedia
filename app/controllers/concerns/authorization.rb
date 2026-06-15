module Authorization
  extend ActiveSupport::Concern

  class NotAuthorized < StandardError; end

  included do
    rescue_from NotAuthorized, with: :deny_access
  end

  private

  def require_login
    return if signed_in?

    store_return_location
    redirect_to new_session_path, alert: I18n.t("auth.sign_in_required")
  end

  def require_moderator
    require_login
    raise NotAuthorized unless current_user&.can_moderate?
  end

  def require_admin
    require_login
    raise NotAuthorized unless current_user&.admin?
  end

  def store_return_location
    session[:return_to_after_authenticating] = request.fullpath if request.get?
  end

  def deny_access
    respond_to do |format|
      format.html { redirect_to localized_root_path, alert: I18n.t("auth.not_authorized") }
      format.any { head :forbidden }
    end
  end
end
