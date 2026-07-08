# Social sign-in. Credentials live in Rails encrypted credentials under `google`
# (see `bin/rails credentials:edit`):
#
#   google:
#     client_id: "…apps.googleusercontent.com"
#     client_secret: "…"
#
# The strategy is a no-op without them, so the app still boots (e.g. in CI or a
# fresh checkout) — the "Continue with Google" button just won't complete.
#
# Apple is intentionally not wired yet: it needs an Apple Developer membership and
# a client secret generated from a .p8 signing key. When ready, add an
# `omniauth-apple` provider block here and a button in the auth views.
Rails.application.config.middleware.use OmniAuth::Builder do
  google = Rails.application.credentials.google

  if google&.client_id.present?
    provider :google_oauth2, google.client_id, google.client_secret, {
      scope: "email,profile",
      prompt: "select_account",
      access_type: "online"
    }
  end
end

# OmniAuth 2 only initiates auth over POST (CSRF-protected). Silence the default
# logger's noise and route errors through our failure endpoint rather than raising.
OmniAuth.config.logger = Rails.logger
OmniAuth.config.on_failure = proc { |env| Sessions::OmniauthController.action(:failure).call(env) }
