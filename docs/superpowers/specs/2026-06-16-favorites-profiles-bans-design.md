# Favorites, Public Profiles & Contribution Bans — Design

Date: 2026-06-16

Three related features that extend the user/account surface of Lurepedia:

1. **Favorites** — users can favorite species, lures, and shops.
2. **Public profiles** — every user has a public profile page (catches, stats, favorites) reachable at a shareable URL, with the URL surfaced in account settings.
3. **Contribution bans** — admins can forbid users from contributing, with configurable scope, a reason, optional expiry, and full history.

All three follow existing codebase patterns: polymorphic associations (à la `Report`/`Upvote`), the `Sluggable` concern, plain-Ruby policies, `require_login`-style gating in the `Authorization` concern, and reuse of `shared/` partials.

---

## 1. Favorites

### Data model

`Favorite` — polymorphic, mirroring `Upvote`/`Report`:

```ruby
class Favorite < ApplicationRecord
  belongs_to :user
  belongs_to :favoritable, polymorphic: true # Species | Lure | Shop
  validates :user_id, uniqueness: { scope: [:favoritable_type, :favoritable_id] }
end
```

Migration: `favorites` table with `user_id`, `favoritable_type`, `favoritable_id`, timestamps; unique index on `[user_id, favoritable_type, favoritable_id]` and an index on `[favoritable_type, favoritable_id]`.

A `Favoritable` model concern provides the inverse side and a convenience predicate:

```ruby
module Favoritable
  extend ActiveSupport::Concern
  included do
    has_many :favorites, as: :favoritable, dependent: :destroy
  end
  def favorited_by?(user)
    return false unless user
    favorites.exists?(user_id: user.id)
  end
end
```

Included into `Species`, `Lure`, `Shop`. `User has_many :favorites, dependent: :destroy`.

### Controller & routes

`FavoritesController` with `#create` and `#destroy`, gated by `require_login` and `require_contribution(:favorites)` (see §3). Uses the polymorphic-param idiom and the `find_or_create_by!` / `destroy_all` pattern from `UpvotesController`. Redirects back to the referring resource (fallback to the resource path).

Routes (inside the localized scope):

```ruby
resources :favorites, only: %i[create destroy]
```

`create` receives `favoritable_type` + `favoritable_id`; `destroy` receives the favorite id (or the same polymorphic params — implementation may look up the user's favorite by polymorphic key to avoid leaking ids). Only `Species`, `Lure`, `Shop` are accepted as `favoritable_type` (whitelist; reject others with `head :unprocessable_entity`).

### UI

`shared/_favorite_button` partial: a toggle (heart/star) shown on the `species#show`, `lures#show`, and `shops#show` pages. Rendered only when `can_contribute?(:favorites)` (hidden for signed-out users and users banned from favoriting — signed-out users instead see a prompt to sign in, matching existing affordance conventions). Submits a Turbo form; on success the button flips state in place.

Favorites are displayed (grouped by type) on the public profile — see §2.

---

## 2. Public profiles

### Identifiers

Two new columns on `users`:

- `slug` (string, not null, unique) — auto-generated: the name parameterized **plus a short opaque token**, e.g. `casey-rivera-8f3a`. The token guarantees uniqueness without exposing collision counters or leaking ordering. Always present and stable once set.
- `username` (string, nullable, unique) — optional, user-editable in settings. Vanity handle. `nil` by default.

`Sluggable` is reused but the User override appends the token:

```ruby
# in User
include Sluggable
private
def slug_source = name
# override ensure_slug behavior to append a short token, or add a
# `slug_token` hook in Sluggable. Implementation detail for the plan.
```

The plan will decide whether to add an optional token hook to `Sluggable` or override `ensure_slug` in `User`. Either way the generated slug is `"#{name.parameterize}-#{SecureRandom.alphanumeric(4).downcase}"`, re-rolled on the rare collision.

`User#to_param` returns `username` if present, else `slug`.

Profile lookup resolves by either handle so old links survive a username change:

```ruby
def self.find_by_handle!(handle)
  find_by(username: handle) || find_by!(slug: handle)
end
```

Validations: `username` — uniqueness (case-insensitive), format (lowercase alphanumeric + hyphen/underscore, length bounds), and must not collide with the reserved set or look like another user's slug. `slug` — presence + uniqueness (from `Sluggable`).

### Route & controller

```ruby
get "u/:handle", to: "profiles#show", as: :profile
```

Public (no login required). `ProfilesController#show`:

- Resolves the user via `find_by_handle!`.
- Loads catches (`user.catches.includes(:species, variant: :lure).recent`) and favorites grouped by type.
- Computes stats: catches count and total upvotes (reusing the `my/catches` calculation).
- Sets `@owner = (current_user == @user)` to toggle management affordances.

### View

`profiles/show.html.erb`:

- **Header**: name, bio, country, member-since, stat tiles (catches, total upvotes).
- **Catches**: grid reusing `shared/_catch_card`.
- **Favorites**: three sections (Species / Lures / Shops), reusing `shared/_lure_card` and simple list/cards for species & shops. Empty sections are hidden (or show an empty hint on the owner's own profile).
- **Owner controls**: when `@owner`, each favorite shows an inline remove control (renders the `_favorite_button` in its "remove" state), and a link to edit settings.

### `my/catches` consolidation

The public profile now shows the user's catches, so `my/catches` is redundant. `My::CatchesController#index` redirects to the current user's profile (`redirect_to profile_path(current_user)`). The route is kept (so existing links/bookmarks and the header menu entry still resolve) but becomes a thin redirect. Header/footer links pointing at `my_catches_path` are repointed at the profile.

### Settings page

A "Your public profile" block in `settings/edit`:

- Shows the full profile URL (`profile_url(current_user)`).
- A copy-to-clipboard button backed by a small Stimulus controller (`clipboard_controller.js`).
- An editable `username` field. `username` is added to `settings_params`. Validation errors render inline as today.

---

## 3. Contribution bans

### Data model

`Ban` is a first-class record — multiple bans per user accumulate as history; the "current" restriction is derived, never overwritten.

```ruby
class Ban < ApplicationRecord
  belongs_to :user
  belongs_to :issued_by, class_name: "User"
  belongs_to :revoked_by, class_name: "User", optional: true

  CAPABILITIES = %w[catalog claims catches comments upvotes reports favorites].freeze
  PRESETS = {
    "catalog_only" => %w[catalog claims],
    "contributions" => %w[catalog claims catches comments reports],
    "full"          => %w[catalog claims catches comments reports upvotes favorites]
  }.freeze

  validates :reason, presence: true
  validate :capabilities_subset

  scope :active, -> { where(revoked_at: nil).where("expires_at IS NULL OR expires_at > ?", Time.current) }

  def active?
    revoked_at.nil? && (expires_at.nil? || expires_at.future?)
  end

  def permanent?  = expires_at.nil?
  def blocks?(capability) = capabilities.include?(capability.to_s)
end
```

Migration: `bans` table — `user_id`, `issued_by_id`, `revoked_by_id` (nullable), `reason:text`, `capabilities:json` (array of capability keys), `expires_at:datetime` (nullable, `nil` = permanent), `revoked_at:datetime` (nullable), timestamps. Indexes on `user_id` and `[user_id, revoked_at, expires_at]` for the active lookup.

`capabilities` is a JSON array. Presets pre-fill the admin form; the admin may then customize to any subset of `CAPABILITIES` ("presets and custom selection").

### User integration

```ruby
# User
has_many :bans, dependent: :destroy

def active_ban
  @active_ban ||= bans.active.order(created_at: :desc).first
end

def blocked_from?(capability)
  active_ban&.blocks?(capability) || false
end
```

### Gating

New helper in the `Authorization` concern:

```ruby
def require_contribution(capability)
  return true unless require_login
  return true unless current_user.blocked_from?(capability)
  redirect_to profile_path(current_user), alert: I18n.t("bans.blocked")
  false
end

def can_contribute?(capability)
  signed_in? && !current_user.blocked_from?(capability)
end
helper_method :can_contribute?
```

Applied as a `before_action` on the relevant create/new/update actions:

- `catches` → `:catches`
- `lures`, `species`, `brands`, `shops` (new/create/edit/update) → `:catalog`
- `claims` → `:claims`
- `comments` → `:comments`
- `upvotes` → `:upvotes`
- `reports` → `:reports`
- `favorites` → `:favorites`

Inside `Editable#commit_edit`, also assert `:catalog` (defense in depth for the suggested-edit path).

Contribution affordances (buttons, "Add"/"Suggest an edit" links, favorite/upvote buttons) are wrapped in `can_contribute?(capability)` so banned users don't see dead buttons.

### Persistent warning

A banner partial (`shared/_ban_notice`) rendered in the application layout whenever `current_user&.active_ban` is present. States: that the account is restricted, the human-readable scope (derived from capabilities), the reason, and the expiry ("until <date>" or "permanent"). Styled as a prominent warning, shown on every page until the ban expires or is lifted.

### Admin UI

`Admin::BansController` (gated by `require_admin`):

- `#index` (per user, e.g. `admin/people/:user_id/bans` or a nested resource): lists the user's full ban history (active, expired, revoked) newest-first, each showing scope, reason, who issued it, when, and expiry/revocation status.
- `#create`: issue-ban form — reason (required), capability selection (preset radio buttons that pre-fill checkboxes + free custom checkboxes), optional `expires_at`. Sets `issued_by: current_user`.
- `#update` (or a dedicated `#revoke` member route): "lift" a ban — sets `revoked_at: Time.current`, `revoked_by: current_user`.

On the existing `admin/people` page, each user row gains an active-ban indicator (badge) and a link to their ban management view. Routes nested under `admin`:

```ruby
namespace :admin do
  resources :users, only: :update do
    resources :bans, only: %i[index create] do
      member { patch :revoke }
    end
  end
end
```

`AdminPolicy` / existing `require_admin` covers authorization. Banning is admin-only (not moderator), consistent with claims/catalog requiring an admin.

---

## Localization

All new user-facing strings added to **all** locale files (`bg, de, el, en, es, fr, ja, nl, ru, zh`): favorite button labels, profile page labels/stats, "your public profile" + copy button, username field + validation messages, ban notice (scope descriptions, reason label, expiry phrasing), admin ban form labels, and the `bans.blocked` flash. Capability and preset labels are translated by key (e.g. `bans.capability.catches`, `bans.preset.catalog_only`), matching the existing enum/condition label convention.

---

## Testing

- **Models**: `Favorite` uniqueness + polymorphic; `Favoritable#favorited_by?`; `User` slug generation (token suffix, stability), `username` uniqueness/format/`to_param`/`find_by_handle!`; `Ban` `active?`/`permanent?`/`blocks?`, `active` scope (revoked + expired excluded), capability validation; `User#active_ban`/`blocked_from?`.
- **Controllers/integration**: favorite create/destroy (incl. duplicate + bad type); profile show for owner vs visitor vs by-username vs by-slug; `my/catches` redirect; settings username update + errors; contribution gating returns redirect+flash for each capability and that affordances hide; admin ban create/revoke + history listing; non-admin cannot reach ban endpoints; banned user sees the persistent banner.
- **Policies**: admin-only ban management.

Tests use fixtures + the existing `sign_in_as` helper and run under the parallelized Minitest suite.

---

## Out of scope

- Notifying users by email when banned (banner-only for now).
- Favoriting anything other than species/lures/shops (e.g. catches, brands).
- Public listing/browse of who-favorited-what beyond the owner's own profile.
- Appeals workflow for bans.
