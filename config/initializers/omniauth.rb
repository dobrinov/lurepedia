# Social sign-in. Credentials live in Rails encrypted credentials (see
# `bin/rails credentials:edit`):
#
#   google:
#     client_id: "…apps.googleusercontent.com"
#     client_secret: "…"
#   apple:
#     client_id: "com.lurepedia.web"   # the Services ID identifier
#     team_id: "XXXXXXXXXX"            # Apple Developer Team ID
#     key_id: "YYYYYYYYYY"             # Key ID of the .p8 signing key
#     private_key: |                   # contents of the AuthKey_*.p8 file
#       -----BEGIN PRIVATE KEY-----
#       …
#       -----END PRIVATE KEY-----
#
# Each strategy is a no-op without its credentials, so the app still boots (CI, a
# fresh checkout) — the button just stays hidden (see ApplicationHelper).
Rails.application.config.middleware.use OmniAuth::Builder do
  google = Rails.application.credentials.google
  apple  = Rails.application.credentials.apple

  if google&.client_id.present?
    provider :google_oauth2, google.client_id, google.client_secret, {
      scope: "email,profile",
      prompt: "select_account",
      access_type: "online"
    }
  end

  if apple&.client_id.present?
    # omniauth-apple mints the JWT client secret from the .p8 key, so the second
    # positional arg (secret) stays empty.
    provider :apple, apple.client_id, "", {
      scope: "email name",
      team_id: apple.team_id,
      key_id: apple.key_id,
      pem: apple.private_key
    }
  end
end

# OmniAuth 2 only initiates auth over POST (CSRF-protected). Silence the default
# logger's noise and route errors through our failure endpoint rather than raising.
OmniAuth.config.logger = Rails.logger
OmniAuth.config.on_failure = proc { |env| Sessions::OmniauthController.action(:failure).call(env) }
