# Sign in with Apple returns its callback as a *cross-site* POST (form_post
# response mode). Browsers withhold SameSite=Lax cookies on cross-site POSTs, so
# the OmniAuth `state`/`nonce` we stash in the session during the request phase
# would come back missing — the callback then blows up verifying a nil nonce
# ("undefined method 'bytesize' for nil"). SameSite=None (which requires Secure,
# provided by force_ssl in production) lets the session cookie survive that
# round-trip. Kept at :lax outside production, where there's no HTTPS to satisfy
# Secure and Apple isn't exercised anyway.
#
# This only affects the Rails session cookie (CSRF token, flash, OmniAuth
# handshake state). The login cookie (`:session_id`, set in the Authentication
# concern) is separate and stays SameSite=Lax, so relaxing this does not widen
# the surface for authenticated-request forgery.
same_site = Rails.env.production? ? :none : :lax

Rails.application.config.session_store :cookie_store,
  key: "_lurepedia_session",
  same_site: same_site,
  secure: Rails.env.production?
