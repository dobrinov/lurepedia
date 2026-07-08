class Sessions::OmniauthController < ApplicationController
  # Apple posts its callback cross-site (form_post) with no Rails CSRF token, so
  # skip forgery protection here — OmniAuth's own `state` parameter is what guards
  # the callback against forgery. The initiating POST to /auth/:provider is still
  # guarded by omniauth-rails_csrf_protection.
  skip_forgery_protection

  rate_limit to: 20, within: 3.minutes, only: :create,
    with: -> { redirect_to new_session_path, alert: t("auth.oauth_failed") }

  def create
    auth = request.env["omniauth.auth"]
    return failure unless auth

    user = User.from_omniauth(auth)
    start_new_session_for(user)
    cookies[:locale] = user.locale

    track_goal(user.previously_new_record? ? "Signup" : "Login", method: auth.provider)
    redirect_to after_authentication_url, notice: t("auth.welcome_back")
  rescue ActiveRecord::RecordInvalid
    failure
  end

  def failure
    redirect_to new_session_path, alert: t("auth.oauth_failed")
  end
end
