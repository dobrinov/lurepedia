module Authorization
  extend ActiveSupport::Concern

  class NotAuthorized < StandardError; end

  included do
    rescue_from NotAuthorized, with: :deny_access
    helper_method :policy if respond_to?(:helper_method)
  end

  # Build a policy: policy(:catch) or policy(record) → infers <Class>Policy.
  def policy(target)
    klass =
      if target.is_a?(Symbol) || target.is_a?(String)
        "#{target.to_s.classify}Policy"
      elsif target.is_a?(Class)
        "#{target.name}Policy"
      else
        "#{target.class.name}Policy"
      end
    record = (target.is_a?(Symbol) || target.is_a?(String) || target.is_a?(Class)) ? nil : target
    klass.constantize.new(current_user, record)
  end

  private

  def require_login
    return true if signed_in?

    store_return_location
    redirect_to new_session_path, alert: I18n.t("auth.sign_in_required")
    false
  end

  def require_moderator
    return unless require_login

    raise NotAuthorized unless current_user.can_moderate?
  end

  def require_admin
    return unless require_login

    raise NotAuthorized unless current_user.admin?
  end

  def store_return_location
    session[:return_to_after_authenticating] = request.fullpath if request.get? || request.head?
  end

  def deny_access
    respond_to do |format|
      format.html { redirect_to localized_root_path, alert: I18n.t("auth.not_authorized") }
      format.any { head :forbidden }
    end
  end
end
