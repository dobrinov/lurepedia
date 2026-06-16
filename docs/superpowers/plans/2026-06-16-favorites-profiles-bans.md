# Favorites, Public Profiles & Contribution Bans Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let users favorite species/lures/shops, give every user a shareable public profile (catches + stats + favorites), and let admins ban users from contributing with configurable scope, reason, expiry, and history.

**Architecture:** Three feature areas built on existing patterns — a polymorphic `Favorite` (like `Upvote`/`Report`), a `ProfilesController` resolving users by `username`-or-`slug`, and a first-class `Ban` model whose active restriction is derived (never overwritten). Contribution gating lives in the `Authorization` concern as `require_contribution(capability)` / `can_contribute?(capability)` and is applied as `before_action`s.

**Tech Stack:** Rails 8.1, SQLite, Hotwire (Turbo + Stimulus via importmap), Minitest with fixtures, plain-Ruby policies, I18n across 10 locales.

---

## File Structure

**Favorites**
- Create: `app/models/favorite.rb`, `app/models/concerns/favoritable.rb`, `app/controllers/favorites_controller.rb`, `app/views/shared/_favorite_button.html.erb`
- Modify: `app/models/species.rb`, `app/models/lure.rb`, `app/models/shop.rb`, `app/models/user.rb`, `config/routes.rb`, `app/views/lures/show.html.erb`, `app/views/species/show.html.erb`, `app/views/shops/*` show
- Migrate: `db/migrate/*_create_favorites.rb`
- Test: `test/models/favorites_test.rb`, `test/integration/favorites_test.rb`

**Public profiles**
- Create: `app/controllers/profiles_controller.rb`, `app/views/profiles/show.html.erb`, `app/javascript/controllers/clipboard_controller.js`
- Modify: `app/models/concerns/sluggable.rb`, `app/models/user.rb`, `app/controllers/my/catches_controller.rb`, `app/controllers/settings_controller.rb`, `app/views/settings/edit.html.erb`, `app/views/layouts/_header.html.erb`, `config/routes.rb`, `test/fixtures/users.yml`, `app/javascript/controllers/index.js`
- Migrate: `db/migrate/*_add_slug_and_username_to_users.rb`
- Test: `test/models/user_test.rb`, `test/integration/profiles_test.rb`

**Contribution bans**
- Create: `app/models/ban.rb`, `app/controllers/admin/bans_controller.rb`, `app/views/admin/bans/index.html.erb`, `app/views/shared/_ban_notice.html.erb`
- Modify: `app/models/user.rb`, `app/controllers/concerns/authorization.rb`, `app/controllers/application_controller.rb`, all contribution controllers, `app/controllers/concerns/editable.rb`, `app/views/layouts/application.html.erb`, `app/views/admin/dashboard/people.html.erb`, `config/routes.rb`
- Migrate: `db/migrate/*_create_bans.rb`
- Test: `test/models/ban_test.rb`, `test/integration/contribution_bans_test.rb`

**Localization (all areas)**
- Modify: `config/locales/{en,bg,de,el,es,fr,ja,nl,ru,zh}.yml`

---

## Part A — Favorites

### Task 1: Favorite model, migration, and Favoritable concern

**Files:**
- Create: `db/migrate/20260616000001_create_favorites.rb`
- Create: `app/models/favorite.rb`
- Create: `app/models/concerns/favoritable.rb`
- Modify: `app/models/species.rb`, `app/models/lure.rb`, `app/models/shop.rb`, `app/models/user.rb`
- Test: `test/models/favorites_test.rb`

- [ ] **Step 1: Write the migration**

Create `db/migrate/20260616000001_create_favorites.rb`:

```ruby
class CreateFavorites < ActiveRecord::Migration[8.1]
  def change
    create_table :favorites do |t|
      t.references :user, null: false, foreign_key: true
      t.references :favoritable, polymorphic: true, null: false
      t.timestamps
    end
    add_index :favorites, [ :user_id, :favoritable_type, :favoritable_id ],
              unique: true, name: "index_favorites_on_user_and_favoritable"
  end
end
```

- [ ] **Step 2: Run the migration**

Run: `bin/rails db:migrate`
Expected: `favorites` table created; `db/schema.rb` updated.

- [ ] **Step 3: Write the failing test**

Create `test/models/favorites_test.rb`:

```ruby
require "test_helper"

class FavoritesTest < ActiveSupport::TestCase
  def setup
    @user = users(:two)
    @brand = Brand.create!(name: "Rapala")
    @type = LureType.create!(key: "crankbait")
    @lure = Lure.create!(brand: @brand, lure_type: @type, model: "DT-6")
    @species = Species.create!(key: "northern_pike")
    @shop = Shop.create!(name: "Tackle Town")
  end

  test "user can favorite a lure, species and shop" do
    Favorite.create!(user: @user, favoritable: @lure)
    Favorite.create!(user: @user, favoritable: @species)
    Favorite.create!(user: @user, favoritable: @shop)
    assert_equal 3, @user.favorites.count
  end

  test "favorites are unique per user and target" do
    Favorite.create!(user: @user, favoritable: @lure)
    dup = Favorite.new(user: @user, favoritable: @lure)
    assert_not dup.valid?
  end

  test "favorited_by? reflects state" do
    assert_not @lure.favorited_by?(@user)
    Favorite.create!(user: @user, favoritable: @lure)
    assert @lure.reload.favorited_by?(@user)
    assert_not @lure.favorited_by?(nil)
  end

  test "destroying a favoritable removes its favorites" do
    Favorite.create!(user: @user, favoritable: @lure)
    @lure.destroy
    assert_equal 0, Favorite.where(favoritable_type: "Lure").count
  end
end
```

- [ ] **Step 4: Run the test to verify it fails**

Run: `bin/rails test test/models/favorites_test.rb`
Expected: FAIL — `uninitialized constant Favorite`.

- [ ] **Step 5: Write the model and concern**

Create `app/models/favorite.rb`:

```ruby
class Favorite < ApplicationRecord
  belongs_to :user
  belongs_to :favoritable, polymorphic: true

  # Only these types may be favorited.
  FAVORITABLE_TYPES = %w[Species Lure Shop].freeze

  validates :user_id, uniqueness: { scope: [ :favoritable_type, :favoritable_id ] }
  validates :favoritable_type, inclusion: { in: FAVORITABLE_TYPES }
end
```

Create `app/models/concerns/favoritable.rb`:

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

- [ ] **Step 6: Wire the concern and associations**

In `app/models/species.rb`, `app/models/lure.rb`, `app/models/shop.rb`, add below the existing `include Sluggable` line:

```ruby
  include Favoritable
```

In `app/models/user.rb`, add to the association block:

```ruby
  has_many :favorites, dependent: :destroy
```

- [ ] **Step 7: Run the test to verify it passes**

Run: `bin/rails test test/models/favorites_test.rb`
Expected: PASS (4 runs, 0 failures).

- [ ] **Step 8: Commit**

```bash
git add db/migrate/20260616000001_create_favorites.rb db/schema.rb app/models/favorite.rb app/models/concerns/favoritable.rb app/models/species.rb app/models/lure.rb app/models/shop.rb app/models/user.rb test/models/favorites_test.rb
git commit -m "Add Favorite model and Favoritable concern"
```

---

### Task 2: FavoritesController and routes

**Files:**
- Create: `app/controllers/favorites_controller.rb`
- Modify: `config/routes.rb`
- Test: `test/integration/favorites_test.rb`

- [ ] **Step 1: Add the route**

In `config/routes.rb`, inside the `scope "(:locale)" ... do` block, near the other `resources`, add:

```ruby
    resources :favorites, only: %i[create destroy]
```

- [ ] **Step 2: Write the failing test**

Create `test/integration/favorites_test.rb`:

```ruby
require "test_helper"

class FavoritesControllerTest < ActionDispatch::IntegrationTest
  def setup
    @user = users(:two)
    brand = Brand.create!(name: "Rapala")
    type = LureType.create!(key: "crankbait")
    @lure = Lure.create!(brand: brand, lure_type: type, model: "DT-6")
  end

  test "signed-out user cannot favorite" do
    post favorites_path(favoritable_type: "Lure", favoritable_id: @lure.id)
    assert_redirected_to new_session_path
  end

  test "signed-in user favorites and unfavorites a lure" do
    sign_in_as(@user)

    assert_difference -> { @user.favorites.count }, 1 do
      post favorites_path(favoritable_type: "Lure", favoritable_id: @lure.id)
    end
    assert @lure.reload.favorited_by?(@user)

    assert_difference -> { @user.favorites.count }, -1 do
      delete favorite_path(favoritable_type: "Lure", favoritable_id: @lure.id)
    end
    assert_not @lure.reload.favorited_by?(@user)
  end

  test "favoriting twice does not error or duplicate" do
    sign_in_as(@user)
    post favorites_path(favoritable_type: "Lure", favoritable_id: @lure.id)
    post favorites_path(favoritable_type: "Lure", favoritable_id: @lure.id)
    assert_equal 1, @user.favorites.count
  end

  test "rejects an unsupported favoritable type" do
    sign_in_as(@user)
    post favorites_path(favoritable_type: "User", favoritable_id: @user.id)
    assert_response :unprocessable_entity
  end
end
```

Note: `destroy` uses the polymorphic key (not a favorite id) so the toggle button never needs to know the favorite's id. The route id segment is unused; pass a placeholder via the path helper as shown (`favorite_path(favoritable_type:, favoritable_id:)` produces `/favorites/...`—see controller lookup below).

- [ ] **Step 3: Run the test to verify it fails**

Run: `bin/rails test test/integration/favorites_test.rb`
Expected: FAIL — `uninitialized constant FavoritesController`.

- [ ] **Step 4: Write the controller**

Create `app/controllers/favorites_controller.rb`:

```ruby
class FavoritesController < ApplicationController
  before_action :require_login
  before_action :set_favoritable

  def create
    Favorite.find_or_create_by!(user: current_user, favoritable: @favoritable)
    redirect_back fallback_location: favoritable_path
  end

  def destroy
    Favorite.where(user: current_user, favoritable: @favoritable).destroy_all
    redirect_back fallback_location: favoritable_path
  end

  private

  def set_favoritable
    type = params[:favoritable_type].to_s
    unless Favorite::FAVORITABLE_TYPES.include?(type)
      head :unprocessable_entity and return
    end
    @favoritable = type.constantize.find(params[:favoritable_id])
  end

  def favoritable_path
    polymorphic_path(@favoritable)
  end
end
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `bin/rails test test/integration/favorites_test.rb`
Expected: PASS (4 runs, 0 failures).

- [ ] **Step 6: Commit**

```bash
git add config/routes.rb app/controllers/favorites_controller.rb test/integration/favorites_test.rb
git commit -m "Add FavoritesController with create/destroy"
```

---

### Task 3: Favorite button partial and show-page integration

**Files:**
- Create: `app/views/shared/_favorite_button.html.erb`
- Modify: `app/views/lures/show.html.erb`, `app/views/species/show.html.erb`, the shops show view
- Test: extend `test/integration/favorites_test.rb`

- [ ] **Step 1: Write the partial**

Create `app/views/shared/_favorite_button.html.erb`. `favoritable` is a local; render only when the viewer may favorite.

```erb
<% if can_contribute?(:favorites) %>
  <% if favoritable.favorited_by?(current_user) %>
    <%= button_to t("favorites.remove"), favorite_path(favoritable_type: favoritable.class.name, favoritable_id: favoritable.id),
          method: :delete, class: "btn btn-fav is-fav" do %>
      ★ <%= t("favorites.favorited") %>
    <% end %>
  <% else %>
    <%= button_to favorites_path(favoritable_type: favoritable.class.name, favoritable_id: favoritable.id),
          method: :post, class: "btn btn-fav" do %>
      ☆ <%= t("favorites.add") %>
    <% end %>
  <% end %>
<% elsif !signed_in? %>
  <%= link_to t("favorites.sign_in_to_favorite"), new_session_path, class: "btn btn-fav" %>
<% end %>
```

- [ ] **Step 2: Add the button to the lure show page**

In `app/views/lures/show.html.erb`, inside the `<div class="row">` that holds the add-catch/edit buttons (around line 50), add after the edit link:

```erb
            <%= render "shared/favorite_button", favoritable: @lure %>
```

- [ ] **Step 3: Add the button to the species and shop show pages**

In `app/views/species/show.html.erb`, locate the primary action row in the hero/header and add `<%= render "shared/favorite_button", favoritable: @species %>`. Do the same in the shops show view with `favoritable: @shop`. (Run `bin/rails routes | grep show` and open each view to find the existing action row; match its placement and surrounding markup.)

- [ ] **Step 4: Write the failing test (button visibility)**

Append to `test/integration/favorites_test.rb`:

```ruby
  test "lure show page renders the favorite button for signed-in users" do
    sign_in_as(@user)
    get lure_path(@lure)
    assert_response :success
    assert_select "form[action=?]", favorites_path(favoritable_type: "Lure", favoritable_id: @lure.id)
  end

  test "lure show page shows sign-in prompt to guests" do
    get lure_path(@lure)
    assert_select "a[href=?]", new_session_path, text: I18n.t("favorites.sign_in_to_favorite")
  end
```

- [ ] **Step 5: Run the test to verify it fails**

Run: `bin/rails test test/integration/favorites_test.rb`
Expected: FAIL — missing `favorites.*` translations and/or `can_contribute?` undefined.

- [ ] **Step 6: Add a temporary `can_contribute?` shim and the en translations**

`can_contribute?` is fully implemented in Task 10. Until then add a shim so the partial renders. In `app/controllers/concerns/authorization.rb`, inside `included do`, add the helper and a stub (the real ban check is added in Task 10):

```ruby
  included do
    rescue_from NotAuthorized, with: :deny_access
    helper_method :policy if respond_to?(:helper_method)
    helper_method :can_contribute? if respond_to?(:helper_method)
  end

  # Replaced with ban-aware logic in the bans feature.
  def can_contribute?(_capability)
    signed_in?
  end
```

Add to `config/locales/en.yml` under a new top-level `favorites:` key:

```yaml
  favorites:
    add: Favorite
    remove: Unfavorite
    favorited: Favorited
    sign_in_to_favorite: Sign in to favorite
```

- [ ] **Step 7: Run the test to verify it passes**

Run: `bin/rails test test/integration/favorites_test.rb`
Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add app/views/shared/_favorite_button.html.erb app/views/lures/show.html.erb app/views/species/show.html.erb app/views/shops app/controllers/concerns/authorization.rb config/locales/en.yml test/integration/favorites_test.rb
git commit -m "Add favorite toggle button to show pages"
```

---

## Part B — Public profiles

### Task 4: User slug + username columns and lookup

**Files:**
- Create: `db/migrate/20260616000002_add_slug_and_username_to_users.rb`
- Modify: `app/models/concerns/sluggable.rb`, `app/models/user.rb`, `test/fixtures/users.yml`
- Test: `test/models/user_test.rb`

- [ ] **Step 1: Write the migration**

Create `db/migrate/20260616000002_add_slug_and_username_to_users.rb`:

```ruby
class AddSlugAndUsernameToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :slug, :string
    add_column :users, :username, :string
    add_index :users, :slug, unique: true
    add_index :users, :username, unique: true

    # Backfill slugs for existing rows so the NOT NULL goal holds going forward.
    reversible do |dir|
      dir.up do
        User.reset_column_information
        User.find_each do |u|
          base = u.name.to_s.parameterize.presence || "angler"
          u.update_columns(slug: "#{base}-#{SecureRandom.alphanumeric(4).downcase}")
        end
        change_column_null :users, :slug, false
      end
    end
  end
end
```

- [ ] **Step 2: Run the migration**

Run: `bin/rails db:migrate`
Expected: columns + unique indexes added; existing users backfilled.

- [ ] **Step 3: Add a token hook to Sluggable**

Modify `app/models/concerns/sluggable.rb`. Add an overridable `slug_suffix` hook and use it when building the base. Replace the `ensure_slug` method body's base-building lines:

```ruby
  private

  def ensure_slug
    return if slug.present?

    base = slug_source.to_s.parameterize
    return if base.blank?

    suffix = slug_suffix
    base = "#{base}-#{suffix}" if suffix.present?

    candidate = base
    i = 2
    while self.class.where(slug: candidate).where.not(id: id).exists?
      candidate = "#{base}-#{i}"
      i += 1
    end
    self.slug = candidate
  end

  # Optional per-model token appended to the slug base (nil = none).
  def slug_suffix
    nil
  end

  # Override in models to choose what the slug is generated from.
  def slug_source
    try(:name) || try(:model)
  end
```

- [ ] **Step 4: Write the failing test**

Append to `test/models/user_test.rb`:

```ruby
  test "generates a slug with an opaque token from the name" do
    user = User.create!(name: "Casey Rivera", email_address: "slugtest@example.com", password: "secret123")
    assert_match(/\Acasey-rivera-[a-z0-9]{4}\z/, user.slug)
  end

  test "to_param prefers username over slug" do
    user = User.create!(name: "Dana Powell", email_address: "dana@example.com", password: "secret123")
    assert_equal user.slug, user.to_param
    user.update!(username: "danap")
    assert_equal "danap", user.to_param
  end

  test "find_by_handle! resolves by username or slug" do
    user = User.create!(name: "Kenji Watanabe", email_address: "kenji@example.com", password: "secret123", username: "kenji")
    assert_equal user, User.find_by_handle!("kenji")
    assert_equal user, User.find_by_handle!(user.slug)
    assert_raises(ActiveRecord::RecordNotFound) { User.find_by_handle!("nope") }
  end

  test "username is downcased, unique, and format-validated" do
    User.create!(name: "A", email_address: "a@example.com", password: "secret123", username: "Taken")
    dup = User.new(name: "B", email_address: "b@example.com", password: "secret123", username: "TAKEN")
    assert_not dup.valid?

    bad = User.new(name: "C", email_address: "c@example.com", password: "secret123", username: "no spaces!")
    assert_not bad.valid?
  end

  test "username cannot collide with another user's slug" do
    other = User.create!(name: "Maria Rossi", email_address: "maria@example.com", password: "secret123")
    clash = User.new(name: "X", email_address: "x@example.com", password: "secret123", username: other.slug)
    assert_not clash.valid?
  end
```

- [ ] **Step 5: Run the test to verify it fails**

Run: `bin/rails test test/models/user_test.rb`
Expected: FAIL — `Sluggable` not included in User / `find_by_handle!` undefined.

- [ ] **Step 6: Implement User slug/username**

In `app/models/user.rb`, add `include Sluggable` at the top of the class body and the username handling:

```ruby
class User < ApplicationRecord
  include Sluggable

  has_secure_password
  # ...existing associations...

  normalizes :email_address, with: ->(e) { e.strip.downcase }
  normalizes :username, with: ->(u) { u.to_s.strip.downcase.presence }

  validates :name, presence: true
  validates :username, uniqueness: { case_sensitive: false },
                       format: { with: /\A[a-z0-9_-]{3,30}\z/ },
                       allow_nil: true
  validate :username_not_taken_as_slug

  def self.find_by_handle!(handle)
    find_by(username: handle) || find_by!(slug: handle)
  end

  def to_param
    username.presence || slug
  end

  # ...existing methods...

  private

  def slug_suffix
    SecureRandom.alphanumeric(4).downcase
  end

  def slug_source
    name
  end

  def username_not_taken_as_slug
    return if username.blank?

    if User.where.not(id: id).exists?(slug: username)
      errors.add(:username, :taken)
    end
  end
end
```

Note: `Sluggable` defines its own `to_param`; the explicit `to_param` above overrides it. Keep the `to_param` method after the include.

- [ ] **Step 7: Add slugs to the users fixture**

Fixtures insert rows directly and skip the `before_validation` callback, so the NOT NULL `slug` needs explicit values. Edit `test/fixtures/users.yml`:

```yaml
one:
  name: Casey Rivera
  email_address: one@example.com
  password_digest: <%= password_digest %>
  role: admin
  country: US
  locale: en
  slug: casey-rivera-aaaa

two:
  name: Marcus Lee
  email_address: two@example.com
  password_digest: <%= password_digest %>
  role: member
  country: SE
  locale: en
  slug: marcus-lee-bbbb
```

- [ ] **Step 8: Run the tests to verify they pass**

Run: `bin/rails test test/models/user_test.rb`
Expected: PASS.

- [ ] **Step 9: Commit**

```bash
git add db/migrate/20260616000002_add_slug_and_username_to_users.rb db/schema.rb app/models/concerns/sluggable.rb app/models/user.rb test/fixtures/users.yml test/models/user_test.rb
git commit -m "Add slug + username to User with handle lookup"
```

---

### Task 5: ProfilesController and route

**Files:**
- Create: `app/controllers/profiles_controller.rb`
- Modify: `config/routes.rb`
- Test: `test/integration/profiles_test.rb`

- [ ] **Step 1: Add the route**

In `config/routes.rb`, inside the localized scope, add near the Discovery routes:

```ruby
    get "u/:handle", to: "profiles#show", as: :profile
```

Also add a `to_param`-aware helper expectation: `profile_path(user)` should yield `/u/<handle>`. Because the route uses `:handle`, define a small helper override is unnecessary — pass the user and Rails will call `to_param`. Confirm by using `profile_path(user)` in views/tests.

- [ ] **Step 2: Write the failing test**

Create `test/integration/profiles_test.rb`:

```ruby
require "test_helper"

class ProfilesControllerTest < ActionDispatch::IntegrationTest
  def setup
    @owner = users(:two)
    brand = Brand.create!(name: "Rapala")
    type = LureType.create!(key: "crankbait")
    @lure = Lure.create!(brand: brand, lure_type: type, model: "DT-6")
    variant = @lure.variants.create!(name: "Firetiger")
    species = Species.create!(key: "largemouth_bass")
    @catch = Catch.create!(user: @owner, variant: variant, species: species, season: :spring, clarity: :clear)
    Favorite.create!(user: @owner, favoritable: @lure)
  end

  test "resolves a profile by slug" do
    get profile_path(@owner.slug)
    assert_response :success
    assert_select "h1", text: /#{@owner.name}/
  end

  test "resolves a profile by username" do
    @owner.update!(username: "marcus")
    get profile_path("marcus")
    assert_response :success
  end

  test "unknown handle is 404" do
    assert_raises(ActiveRecord::RecordNotFound) { get profile_path("ghost") }
  end

  test "profile shows the user's catches and favorites" do
    get profile_path(@owner)
    assert_select ".grid-catches"
    assert_select "body", text: /#{@lure.model}/
  end
end
```

- [ ] **Step 3: Run the test to verify it fails**

Run: `bin/rails test test/integration/profiles_test.rb`
Expected: FAIL — `uninitialized constant ProfilesController`.

- [ ] **Step 4: Write the controller**

Create `app/controllers/profiles_controller.rb`:

```ruby
class ProfilesController < ApplicationController
  def show
    @user = User.find_by_handle!(params[:handle])
    @owner = current_user == @user
    @catches = @user.catches.includes(:species, variant: :lure).recent
    @total_upvotes = @catches.sum(&:upvotes_count)
    @favorite_species = favorites_of("Species")
    @favorite_lures = favorites_of("Lure")
    @favorite_shops = favorites_of("Shop")
  end

  private

  # Resolved favoritable records of one type, newest first.
  # Favorites are few per user, so per-record loading is acceptable here and
  # matches the app's existing simple query patterns.
  def favorites_of(type)
    @user.favorites.where(favoritable_type: type).order(created_at: :desc).map(&:favoritable).compact
  end
end
```

- [ ] **Step 5: Run the test to verify it fails on the view**

Run: `bin/rails test test/integration/profiles_test.rb`
Expected: FAIL — missing template `profiles/show`.

- [ ] **Step 6: Commit the controller (view added next task)**

```bash
git add config/routes.rb app/controllers/profiles_controller.rb test/integration/profiles_test.rb
git commit -m "Add ProfilesController resolving users by handle"
```

---

### Task 6: Profile view

**Files:**
- Create: `app/views/profiles/show.html.erb`
- Modify: `config/locales/en.yml`
- Test: `test/integration/profiles_test.rb` (already written in Task 5)

- [ ] **Step 1: Add en translations**

Add to `config/locales/en.yml` under a new `profile:` key:

```yaml
  profile:
    catches: Catches
    total_upvotes: Total upvotes
    member_since: Member since
    favorite_species: Favorite species
    favorite_lures: Favorite lures
    favorite_shops: Favorite shops
    no_favorites: No favorites yet.
    no_catches: No catches yet.
    your_profile: This is your public profile.
```

- [ ] **Step 2: Write the view**

Create `app/views/profiles/show.html.erb`:

```erb
<% content_for :title, @user.name %>
<div class="container" style="padding-top:24px">
  <div class="page-head">
    <div class="row" style="gap:12px;align-items:center">
      <%= country_flag(@user.country, size: 22) %>
      <div>
        <h1><%= @user.name %></h1>
        <% if @user.bio.present? %><p class="muted"><%= @user.bio %></p><% end %>
        <div class="sub muted"><%= t("profile.member_since") %> <%= l(@user.created_at.to_date, format: :long) %></div>
      </div>
    </div>
    <div class="row" style="gap:24px">
      <div><strong><%= @catches.size %></strong> <span class="muted"><%= t("profile.catches") %></span></div>
      <div><strong><%= @total_upvotes %></strong> <span class="muted"><%= t("profile.total_upvotes") %></span></div>
    </div>
  </div>

  <% if @owner %><div class="flash notice"><%= t("profile.your_profile") %></div><% end %>

  <section>
    <div class="section-head"><h2><%= t("profile.catches") %></h2></div>
    <% if @catches.any? %>
      <div class="grid-catches">
        <% @catches.each do |c| %><%= render "shared/catch_card", catch: c %><% end %>
      </div>
    <% else %>
      <p class="muted"><%= t("profile.no_catches") %></p>
    <% end %>
  </section>

  <% {
       "profile.favorite_species" => @favorite_species,
       "profile.favorite_lures"   => @favorite_lures,
       "profile.favorite_shops"   => @favorite_shops
     }.each do |label_key, records| %>
    <section style="margin-top:32px">
      <div class="section-head"><h2><%= t(label_key) %></h2></div>
      <% if records.any? %>
        <div class="grid-cards">
          <% records.each do |record| %>
            <div class="row" style="justify-content:space-between;align-items:center;gap:12px">
              <%= link_to (record.try(:title) || record.try(:common_name) || record.try(:name)), polymorphic_path(record) %>
              <% if @owner %>
                <%= render "shared/favorite_button", favoritable: record %>
              <% end %>
            </div>
          <% end %>
        </div>
      <% else %>
        <p class="muted"><%= t("profile.no_favorites") %></p>
      <% end %>
    </section>
  <% end %>
</div>
```

- [ ] **Step 3: Run the tests to verify they pass**

Run: `bin/rails test test/integration/profiles_test.rb`
Expected: PASS (4 runs, 0 failures).

- [ ] **Step 4: Commit**

```bash
git add app/views/profiles/show.html.erb config/locales/en.yml
git commit -m "Add public profile view with catches and favorites"
```

---

### Task 7: Redirect my/catches to profile and repoint header

**Files:**
- Modify: `app/controllers/my/catches_controller.rb`, `app/views/layouts/_header.html.erb`
- Test: `test/integration/profiles_test.rb`

- [ ] **Step 1: Write the failing test**

Append to `test/integration/profiles_test.rb`:

```ruby
  test "my/catches redirects to the owner's profile" do
    sign_in_as(@owner)
    get my_catches_path
    assert_redirected_to profile_path(@owner)
  end

  test "my/catches requires login" do
    get my_catches_path
    assert_redirected_to new_session_path
  end
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bin/rails test test/integration/profiles_test.rb`
Expected: FAIL — currently renders the index instead of redirecting.

- [ ] **Step 3: Make my/catches a redirect**

Replace `app/controllers/my/catches_controller.rb` with:

```ruby
module My
  class CatchesController < ApplicationController
    before_action :require_login

    def index
      redirect_to profile_path(current_user)
    end
  end
end
```

- [ ] **Step 4: Repoint the header link**

In `app/views/layouts/_header.html.erb` line ~46, change:

```erb
            <%= link_to t("dashboard.my_catches"), my_catches_path %>
```

to:

```erb
            <%= link_to t("dashboard.my_catches"), profile_path(current_user) %>
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `bin/rails test test/integration/profiles_test.rb`
Expected: PASS.

- [ ] **Step 6: Delete the now-unused view**

Run: `git rm app/views/my/catches/index.html.erb`

- [ ] **Step 7: Run the full suite to catch broken references**

Run: `bin/rails test`
Expected: PASS (any failure here is a stale `my_catches` assumption — fix the reference).

- [ ] **Step 8: Commit**

```bash
git add app/controllers/my/catches_controller.rb app/views/layouts/_header.html.erb test/integration/profiles_test.rb
git commit -m "Redirect my/catches to public profile"
```

---

### Task 8: Settings — username field, profile URL, copy button

**Files:**
- Create: `app/javascript/controllers/clipboard_controller.js`
- Modify: `app/javascript/controllers/index.js`, `app/controllers/settings_controller.rb`, `app/views/settings/edit.html.erb`, `config/locales/en.yml`
- Test: `test/integration/profiles_test.rb`

- [ ] **Step 1: Write the failing test**

Append to `test/integration/profiles_test.rb`:

```ruby
  test "settings shows the public profile url and accepts a username" do
    sign_in_as(@owner)
    get edit_settings_path
    assert_response :success
    assert_select "input[name=?]", "user[username]"

    patch settings_path, params: { user: { username: "marcus-l" } }
    assert_equal "marcus-l", @owner.reload.username
  end

  test "invalid username is rejected with an error" do
    sign_in_as(@owner)
    patch settings_path, params: { user: { username: "no spaces" } }
    assert_response :unprocessable_entity
    assert_nil @owner.reload.username
  end
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bin/rails test test/integration/profiles_test.rb`
Expected: FAIL — username not permitted / field missing.

- [ ] **Step 3: Permit username in settings**

In `app/controllers/settings_controller.rb`, update `settings_params`:

```ruby
  def settings_params
    params.require(:user).permit(:name, :bio, :country, :locale, :units, :username)
  end
```

- [ ] **Step 4: Write the clipboard Stimulus controller**

Create `app/javascript/controllers/clipboard_controller.js`:

```javascript
import { Controller } from "@hotwired/stimulus"

// Copies the value of the source target to the clipboard.
export default class extends Controller {
  static targets = ["source", "button"]

  copy() {
    navigator.clipboard.writeText(this.sourceTarget.value).then(() => {
      const btn = this.hasButtonTarget ? this.buttonTarget : null
      if (!btn) return
      const original = btn.textContent
      btn.textContent = btn.dataset.copiedLabel || "Copied!"
      setTimeout(() => { btn.textContent = original }, 1500)
    })
  }
}
```

- [ ] **Step 5: Register the controller**

In `app/javascript/controllers/index.js`, follow the existing registration style (eager registration list) and add:

```javascript
import ClipboardController from "controllers/clipboard_controller"
application.register("clipboard", ClipboardController)
```

(Match the exact import/register form already used in that file for the other controllers.)

- [ ] **Step 6: Add the settings UI**

In `app/views/settings/edit.html.erb`, add a "Your public profile" block inside the form (near the other fields). Use the existing form builder variable (open the file to confirm it is `f`):

```erb
<div class="field" data-controller="clipboard">
  <label><%= t("settings.public_profile") %></label>
  <div class="row" style="gap:8px">
    <input type="text" class="input" readonly
           value="<%= profile_url(@user) %>"
           data-clipboard-target="source">
    <button type="button" class="btn"
            data-action="clipboard#copy"
            data-clipboard-target="button"
            data-copied-label="<%= t('settings.copied') %>"><%= t("settings.copy") %></button>
  </div>
</div>

<div class="field">
  <%= f.label :username, t("settings.username") %>
  <%= f.text_field :username, class: "input", placeholder: t("settings.username_hint") %>
  <span class="muted" style="font-size:13px"><%= t("settings.username_help") %></span>
</div>
```

- [ ] **Step 7: Add en translations**

Add under `settings:` in `config/locales/en.yml`:

```yaml
    public_profile: Your public profile
    copy: Copy
    copied: Copied!
    username: Username
    username_hint: e.g. casey-rivera
    username_help: Optional. Lowercase letters, numbers, hyphens. Used in your profile URL.
```

- [ ] **Step 8: Run the tests to verify they pass**

Run: `bin/rails test test/integration/profiles_test.rb`
Expected: PASS.

- [ ] **Step 9: Commit**

```bash
git add app/javascript/controllers/clipboard_controller.js app/javascript/controllers/index.js app/controllers/settings_controller.rb app/views/settings/edit.html.erb config/locales/en.yml test/integration/profiles_test.rb
git commit -m "Add username + copyable profile URL to settings"
```

---

## Part C — Contribution bans

### Task 9: Ban model, migration, and User integration

**Files:**
- Create: `db/migrate/20260616000003_create_bans.rb`, `app/models/ban.rb`
- Modify: `app/models/user.rb`
- Test: `test/models/ban_test.rb`

- [ ] **Step 1: Write the migration**

Create `db/migrate/20260616000003_create_bans.rb`:

```ruby
class CreateBans < ActiveRecord::Migration[8.1]
  def change
    create_table :bans do |t|
      t.references :user, null: false, foreign_key: true
      t.references :issued_by, null: false, foreign_key: { to_table: :users }
      t.references :revoked_by, null: true, foreign_key: { to_table: :users }
      t.text :reason, null: false
      t.json :capabilities, null: false, default: []
      t.datetime :expires_at
      t.datetime :revoked_at
      t.timestamps
    end
    add_index :bans, [ :user_id, :revoked_at, :expires_at ]
  end
end
```

- [ ] **Step 2: Run the migration**

Run: `bin/rails db:migrate`
Expected: `bans` table created.

- [ ] **Step 3: Write the failing test**

Create `test/models/ban_test.rb`:

```ruby
require "test_helper"

class BanTest < ActiveSupport::TestCase
  def setup
    @user = users(:two)
    @admin = users(:one)
  end

  def ban(**attrs)
    Ban.create!({ user: @user, issued_by: @admin, reason: "spam", capabilities: %w[catalog] }.merge(attrs))
  end

  test "requires a reason" do
    b = Ban.new(user: @user, issued_by: @admin, capabilities: %w[catalog])
    assert_not b.valid?
  end

  test "capabilities must be a subset of CAPABILITIES" do
    b = Ban.new(user: @user, issued_by: @admin, reason: "x", capabilities: %w[bogus])
    assert_not b.valid?
  end

  test "active scope excludes revoked and expired bans" do
    active = ban
    ban(revoked_at: Time.current)
    ban(expires_at: 1.day.ago)
    assert_equal [ active ], Ban.active.to_a
  end

  test "active? reflects revoked and expiry state" do
    assert ban.active?
    assert_not ban(revoked_at: Time.current).active?
    assert_not ban(expires_at: 1.hour.ago).active?
    assert ban(expires_at: 1.hour.from_now).active?
  end

  test "permanent? when no expiry" do
    assert ban.permanent?
    assert_not ban(expires_at: 1.day.from_now).permanent?
  end

  test "blocks? checks capability membership" do
    b = ban(capabilities: %w[catalog catches])
    assert b.blocks?(:catches)
    assert_not b.blocks?(:comments)
  end

  test "user active_ban and blocked_from?" do
    assert_nil @user.active_ban
    ban(capabilities: %w[catches])
    @user.reload
    assert @user.active_ban
    assert @user.blocked_from?(:catches)
    assert_not @user.blocked_from?(:comments)
  end

  test "presets expose capability sets" do
    assert_equal %w[catalog claims], Ban::PRESETS["catalog_only"]
    assert Ban::PRESETS.key?("full")
  end
end
```

- [ ] **Step 4: Run the test to verify it fails**

Run: `bin/rails test test/models/ban_test.rb`
Expected: FAIL — `uninitialized constant Ban`.

- [ ] **Step 5: Write the Ban model**

Create `app/models/ban.rb`:

```ruby
class Ban < ApplicationRecord
  belongs_to :user
  belongs_to :issued_by, class_name: "User"
  belongs_to :revoked_by, class_name: "User", optional: true

  CAPABILITIES = %w[catalog claims catches comments upvotes reports favorites].freeze
  PRESETS = {
    "catalog_only"  => %w[catalog claims],
    "contributions" => %w[catalog claims catches comments reports],
    "full"          => %w[catalog claims catches comments reports upvotes favorites]
  }.freeze

  validates :reason, presence: true
  validate :capabilities_subset

  scope :active, -> { where(revoked_at: nil).where("expires_at IS NULL OR expires_at > ?", Time.current) }
  scope :newest_first, -> { order(created_at: :desc) }

  def active?
    revoked_at.nil? && (expires_at.nil? || expires_at.future?)
  end

  def permanent?
    expires_at.nil?
  end

  def blocks?(capability)
    capabilities.include?(capability.to_s)
  end

  private

  def capabilities_subset
    extra = Array(capabilities).map(&:to_s) - CAPABILITIES
    errors.add(:capabilities, :invalid) if extra.any?
  end
end
```

- [ ] **Step 6: Add User integration**

In `app/models/user.rb`, add the association and helpers:

```ruby
  has_many :bans, dependent: :destroy

  def active_ban
    @active_ban ||= bans.active.newest_first.first
  end

  def blocked_from?(capability)
    active_ban&.blocks?(capability) || false
  end
```

- [ ] **Step 7: Run the tests to verify they pass**

Run: `bin/rails test test/models/ban_test.rb`
Expected: PASS (9 runs, 0 failures).

- [ ] **Step 8: Commit**

```bash
git add db/migrate/20260616000003_create_bans.rb db/schema.rb app/models/ban.rb app/models/user.rb test/models/ban_test.rb
git commit -m "Add Ban model with capability scopes and User helpers"
```

---

### Task 10: Contribution gating in Authorization

**Files:**
- Modify: `app/controllers/concerns/authorization.rb`, contribution controllers, `app/controllers/concerns/editable.rb`, `config/locales/en.yml`
- Test: `test/integration/contribution_bans_test.rb`

- [ ] **Step 1: Write the failing test**

Create `test/integration/contribution_bans_test.rb`:

```ruby
require "test_helper"

class ContributionBansTest < ActionDispatch::IntegrationTest
  def setup
    @user = users(:two)
    @admin = users(:one)
    @brand = Brand.create!(name: "Rapala")
    @type = LureType.create!(key: "crankbait")
    @lure = Lure.create!(brand: @brand, lure_type: @type, model: "DT-6")
    @variant = @lure.variants.create!(name: "Firetiger")
    @species = Species.create!(key: "largemouth_bass")
  end

  def ban!(capabilities)
    Ban.create!(user: @user, issued_by: @admin, reason: "testing", capabilities: capabilities)
  end

  test "banned-from-catches user is blocked from creating a catch" do
    ban!(%w[catches])
    sign_in_as(@user)
    assert_no_difference -> { Catch.count } do
      post catches_path, params: { catch: { variant_id: @variant.id, species_id: @species.id, season: "spring" } }
    end
    assert_redirected_to profile_path(@user)
  end

  test "banned-from-favorites user is blocked from favoriting" do
    ban!(%w[favorites])
    sign_in_as(@user)
    assert_no_difference -> { Favorite.count } do
      post favorites_path(favoritable_type: "Lure", favoritable_id: @lure.id)
    end
  end

  test "unbanned capability still works" do
    ban!(%w[catalog])
    sign_in_as(@user)
    assert_difference -> { Favorite.count }, 1 do
      post favorites_path(favoritable_type: "Lure", favoritable_id: @lure.id)
    end
  end

  test "can_contribute? helper reflects the ban" do
    ban!(%w[favorites])
    sign_in_as(@user)
    get lure_path(@lure)
    # Favorite button hidden, sign-in prompt not shown (user is signed in)
    assert_select "form[action=?]", favorites_path(favoritable_type: "Lure", favoritable_id: @lure.id), count: 0
  end
end
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bin/rails test test/integration/contribution_bans_test.rb`
Expected: FAIL — catch/favorite still created (no gating yet).

- [ ] **Step 3: Implement the real gating in Authorization**

In `app/controllers/concerns/authorization.rb`, replace the temporary `can_contribute?` shim (added in Task 3) and add `require_contribution`:

```ruby
  def require_contribution(capability)
    return false unless require_login
    return true unless current_user.blocked_from?(capability)

    redirect_to profile_path(current_user), alert: I18n.t("bans.blocked")
    false
  end

  def can_contribute?(capability)
    signed_in? && !current_user.blocked_from?(capability)
  end
```

Keep the `helper_method :can_contribute?` registration from Task 3.

- [ ] **Step 4: Apply gating to contribution controllers**

Add `before_action` filters (place after existing `require_login`/`before_action` lines):

- `app/controllers/catches_controller.rb` — on create (and new): `before_action -> { require_contribution(:catches) }, only: %i[new create]`
- `app/controllers/favorites_controller.rb` — `before_action -> { require_contribution(:favorites) }`
- `app/controllers/comments_controller.rb` — `before_action -> { require_contribution(:comments) }`
- `app/controllers/upvotes_controller.rb` — `before_action -> { require_contribution(:upvotes) }`
- `app/controllers/reports_controller.rb` — `before_action -> { require_contribution(:reports) }`
- `app/controllers/claims_controller.rb` — `before_action -> { require_contribution(:claims) }`
- `app/controllers/lures_controller.rb`, `species_controller.rb`, `brands_controller.rb`, `shops_controller.rb` — `before_action -> { require_contribution(:catalog) }, only: %i[new create edit update]`

For each, open the file and confirm the action names exist before restricting `only:`. Example for `catches_controller.rb`:

```ruby
class CatchesController < ApplicationController
  before_action :require_login, only: %i[new create]
  before_action -> { require_contribution(:catches) }, only: %i[new create]
  # ...
```

- [ ] **Step 5: Guard the suggested-edit path in Editable**

In `app/controllers/concerns/editable.rb`, at the top of `commit_edit`, add a defense-in-depth check:

```ruby
  def commit_edit(record, attrs, name, redirect_path)
    return unless require_contribution(:catalog)

    if current_user&.admin?
    # ...rest unchanged...
```

- [ ] **Step 6: Add the en translation**

Add to `config/locales/en.yml` under a new `bans:` key:

```yaml
  bans:
    blocked: Your account is currently restricted from this action.
```

- [ ] **Step 7: Run the tests to verify they pass**

Run: `bin/rails test test/integration/contribution_bans_test.rb`
Expected: PASS.

- [ ] **Step 8: Run the full suite**

Run: `bin/rails test`
Expected: PASS — confirm gating didn't break existing contribution tests.

- [ ] **Step 9: Commit**

```bash
git add app/controllers/concerns/authorization.rb app/controllers/concerns/editable.rb app/controllers/*.rb config/locales/en.yml test/integration/contribution_bans_test.rb
git commit -m "Gate contributions behind ban capability checks"
```

---

### Task 11: Persistent ban notice banner

**Files:**
- Create: `app/views/shared/_ban_notice.html.erb`
- Modify: `app/views/layouts/application.html.erb`, `config/locales/en.yml`
- Test: `test/integration/contribution_bans_test.rb`

- [ ] **Step 1: Write the failing test**

Append to `test/integration/contribution_bans_test.rb`:

```ruby
  test "banned user sees a persistent ban notice with reason" do
    Ban.create!(user: @user, issued_by: @admin, reason: "Repeated spam", capabilities: %w[catalog catches], expires_at: 3.days.from_now)
    sign_in_as(@user)
    get lure_path(@lure)
    assert_select ".ban-notice", text: /Repeated spam/
  end

  test "unbanned user sees no ban notice" do
    sign_in_as(@user)
    get lure_path(@lure)
    assert_select ".ban-notice", count: 0
  end
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bin/rails test test/integration/contribution_bans_test.rb`
Expected: FAIL — `.ban-notice` not present.

- [ ] **Step 3: Write the banner partial**

Create `app/views/shared/_ban_notice.html.erb`:

```erb
<% ban = current_user&.active_ban %>
<% if ban %>
  <div class="ban-notice flash alert" role="alert">
    <strong><%= t("bans.notice.title") %></strong>
    <span><%= t("bans.notice.reason") %>: <%= ban.reason %></span>
    <span>
      <% if ban.permanent? %>
        <%= t("bans.notice.permanent") %>
      <% else %>
        <%= t("bans.notice.until", date: l(ban.expires_at.to_date, format: :long)) %>
      <% end %>
    </span>
    <span class="muted">
      <%= t("bans.notice.scope") %>:
      <%= ban.capabilities.map { |c| t("bans.capability.#{c}") }.to_sentence %>
    </span>
  </div>
<% end %>
```

- [ ] **Step 4: Render it in the layout**

In `app/views/layouts/application.html.erb`, add inside `<body>` right after the flash render:

```erb
    <%= render "layouts/header" %>
    <%= render "layouts/flash" %>
    <%= render "shared/ban_notice" %>
```

- [ ] **Step 5: Add en translations**

Add under `bans:` in `config/locales/en.yml`:

```yaml
    notice:
      title: Your account is restricted.
      reason: Reason
      permanent: This restriction is permanent.
      until: "In effect until %{date}."
      scope: Restricted actions
    capability:
      catalog: catalog edits
      claims: ownership claims
      catches: logging catches
      comments: comments
      upvotes: upvotes
      reports: reports
      favorites: favorites
```

- [ ] **Step 6: Run the tests to verify they pass**

Run: `bin/rails test test/integration/contribution_bans_test.rb`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add app/views/shared/_ban_notice.html.erb app/views/layouts/application.html.erb config/locales/en.yml test/integration/contribution_bans_test.rb
git commit -m "Show persistent ban notice to restricted users"
```

---

### Task 12: Admin ban management

**Files:**
- Create: `app/controllers/admin/bans_controller.rb`, `app/views/admin/bans/index.html.erb`
- Modify: `config/routes.rb`, `app/views/admin/dashboard/people.html.erb`, `config/locales/en.yml`
- Test: `test/integration/contribution_bans_test.rb`

- [ ] **Step 1: Add routes**

In `config/routes.rb`, change the `namespace :admin` block's users resource to nest bans:

```ruby
    namespace :admin do
      root to: "dashboard#overview"
      get "people", to: "dashboard#people"
      get "activity", to: "dashboard#activity"
      resources :users, only: :update do
        resources :bans, only: %i[index create] do
          member { patch :revoke }
        end
      end
    end
```

- [ ] **Step 2: Write the failing test**

Append to `test/integration/contribution_bans_test.rb`:

```ruby
  test "admin can issue a ban from a preset" do
    sign_in_as(@admin)
    assert_difference -> { @user.bans.count }, 1 do
      post admin_user_bans_path(@user), params: {
        ban: { reason: "spamming", preset: "contributions", expires_at: "" }
      }
    end
    assert @user.reload.blocked_from?(:catches)
  end

  test "admin can issue a ban with custom capabilities" do
    sign_in_as(@admin)
    post admin_user_bans_path(@user), params: {
      ban: { reason: "edits only", capabilities: %w[catalog], expires_at: "" }
    }
    assert @user.reload.blocked_from?(:catalog)
    assert_not @user.blocked_from?(:catches)
  end

  test "admin can revoke a ban" do
    ban = Ban.create!(user: @user, issued_by: @admin, reason: "x", capabilities: %w[catches])
    sign_in_as(@admin)
    patch revoke_admin_user_ban_path(@user, ban)
    assert_not_nil ban.reload.revoked_at
    assert_equal @admin, ban.revoked_by
  end

  test "non-admin cannot reach ban management" do
    sign_in_as(@user)
    get admin_user_bans_path(@user)
    assert_redirected_to localized_root_path
  end

  test "ban history lists all bans for the user" do
    Ban.create!(user: @user, issued_by: @admin, reason: "old", capabilities: %w[catches], revoked_at: Time.current, revoked_by: @admin)
    Ban.create!(user: @user, issued_by: @admin, reason: "current", capabilities: %w[catalog])
    sign_in_as(@admin)
    get admin_user_bans_path(@user)
    assert_response :success
    assert_select "body", text: /old/
    assert_select "body", text: /current/
  end
```

- [ ] **Step 3: Run the test to verify it fails**

Run: `bin/rails test test/integration/contribution_bans_test.rb`
Expected: FAIL — `uninitialized constant Admin::BansController`.

- [ ] **Step 4: Write the controller**

Create `app/controllers/admin/bans_controller.rb`:

```ruby
module Admin
  class BansController < ApplicationController
    before_action :require_admin
    before_action :set_user

    def index
      @bans = @user.bans.newest_first
      @ban = Ban.new
    end

    def create
      @ban = @user.bans.new(ban_attrs)
      @ban.issued_by = current_user
      if @ban.save
        redirect_to admin_user_bans_path(@user), notice: t("bans.admin.created")
      else
        @bans = @user.bans.newest_first
        flash.now[:alert] = @ban.errors.full_messages.to_sentence
        render :index, status: :unprocessable_entity
      end
    end

    def revoke
      ban = @user.bans.find(params[:id])
      ban.update!(revoked_at: Time.current, revoked_by: current_user)
      redirect_to admin_user_bans_path(@user), notice: t("bans.admin.revoked")
    end

    private

    def set_user
      @user = User.find(params[:user_id])
    end

    # Capabilities come from a preset (if chosen) or explicit checkboxes.
    def ban_attrs
      raw = params.require(:ban).permit(:reason, :expires_at, :preset, capabilities: [])
      preset = raw.delete(:preset)
      caps = Array(raw[:capabilities]).reject(&:blank?)
      caps = Ban::PRESETS.fetch(preset) if preset.present? && Ban::PRESETS.key?(preset)
      raw[:capabilities] = caps
      raw[:expires_at] = raw[:expires_at].presence
      raw
    end
  end
end
```

- [ ] **Step 5: Write the index/management view**

Create `app/views/admin/bans/index.html.erb`:

```erb
<% content_for :title, t("bans.admin.title", name: @user.name) %>
<div class="container">
  <%= render "admin/nav" %>

  <div class="page-head">
    <h1><%= t("bans.admin.title", name: @user.name) %></h1>
    <%= link_to t("admin.people"), admin_people_path, class: "btn btn-sm" %>
  </div>

  <div class="card" style="padding:16px;margin-bottom:24px">
    <h2><%= t("bans.admin.new") %></h2>
    <%= form_with model: @ban, url: admin_user_bans_path(@user), method: :post do |f| %>
      <div class="field">
        <%= f.label :reason, t("bans.admin.reason") %>
        <%= f.text_area :reason, class: "input", rows: 2 %>
      </div>
      <div class="field">
        <%= f.label :preset, t("bans.admin.preset") %>
        <%= f.select :preset,
              Ban::PRESETS.keys.map { |k| [ t("bans.preset.#{k}"), k ] },
              { include_blank: t("bans.admin.custom") }, class: "input" %>
      </div>
      <fieldset class="field">
        <legend><%= t("bans.admin.capabilities") %></legend>
        <% Ban::CAPABILITIES.each do |cap| %>
          <label class="row" style="gap:6px">
            <%= check_box_tag "ban[capabilities][]", cap, false %>
            <%= t("bans.capability.#{cap}") %>
          </label>
        <% end %>
        <p class="muted" style="font-size:13px"><%= t("bans.admin.capabilities_help") %></p>
      </fieldset>
      <div class="field">
        <%= f.label :expires_at, t("bans.admin.expires_at") %>
        <%= f.datetime_local_field :expires_at, class: "input" %>
        <span class="muted" style="font-size:13px"><%= t("bans.admin.permanent_hint") %></span>
      </div>
      <%= f.submit t("bans.admin.issue"), class: "btn btn-primary" %>
    <% end %>
  </div>

  <div class="card" style="overflow-x:auto">
    <table class="lb-table">
      <thead>
        <tr>
          <th><%= t("bans.admin.status") %></th>
          <th><%= t("bans.admin.reason") %></th>
          <th><%= t("bans.admin.scope") %></th>
          <th><%= t("bans.admin.expires_at") %></th>
          <th><%= t("admin.joined") %></th>
          <th></th>
        </tr>
      </thead>
      <tbody>
        <% @bans.each do |ban| %>
          <tr>
            <td>
              <% if ban.active? %><span class="role-badge role-admin"><%= t("bans.admin.active") %></span>
              <% elsif ban.revoked_at %><span class="muted"><%= t("bans.admin.lifted") %></span>
              <% else %><span class="muted"><%= t("bans.admin.expired") %></span><% end %>
            </td>
            <td><%= ban.reason %></td>
            <td class="muted"><%= ban.capabilities.map { |c| t("bans.capability.#{c}") }.to_sentence %></td>
            <td class="muted"><%= ban.permanent? ? t("bans.notice.permanent") : l(ban.expires_at, format: :long) %></td>
            <td class="muted"><%= l(ban.created_at.to_date, format: :long) %></td>
            <td>
              <% if ban.active? %>
                <%= button_to t("bans.admin.lift"), revoke_admin_user_ban_path(@user, ban), method: :patch, class: "btn btn-sm" %>
              <% end %>
            </td>
          </tr>
        <% end %>
      </tbody>
    </table>
  </div>
</div>
```

- [ ] **Step 6: Add the people-page indicator + link**

In `app/views/admin/dashboard/people.html.erb`, add a column. In the `<thead>` row add `<th><%= t("bans.admin.title_short") %></th>` and in the body row (after the role cell) add:

```erb
            <td>
              <% if user.active_ban %><span class="role-badge role-admin"><%= t("bans.admin.active") %></span><% end %>
              <%= link_to t("bans.admin.manage"), admin_user_bans_path(user), class: "btn btn-sm" %>
            </td>
```

- [ ] **Step 7: Add en translations**

Add under `bans:` in `config/locales/en.yml`:

```yaml
    preset:
      catalog_only: Catalog only
      contributions: All contributions
      full: Full (read-only account)
    admin:
      title: "Bans — %{name}"
      title_short: Bans
      new: Issue a ban
      reason: Reason
      preset: Preset
      custom: Custom selection
      capabilities: Restricted actions
      capabilities_help: A preset pre-selects actions; check boxes to customize.
      expires_at: Expires at
      permanent_hint: Leave blank for a permanent ban.
      issue: Issue ban
      status: Status
      scope: Scope
      active: Active
      lifted: Lifted
      expired: Expired
      lift: Lift ban
      manage: Manage bans
      created: Ban issued.
      revoked: Ban lifted.
```

- [ ] **Step 8: Run the tests to verify they pass**

Run: `bin/rails test test/integration/contribution_bans_test.rb`
Expected: PASS.

- [ ] **Step 9: Commit**

```bash
git add app/controllers/admin/bans_controller.rb app/views/admin/bans/index.html.erb config/routes.rb app/views/admin/dashboard/people.html.erb config/locales/en.yml test/integration/contribution_bans_test.rb
git commit -m "Add admin ban management with history and presets"
```

---

### Task 13: Localization sweep across all locales

**Files:**
- Modify: `config/locales/{bg,de,el,es,fr,ja,nl,ru,zh}.yml`
- Test: a guard test ensuring locale key parity

- [ ] **Step 1: Write the failing parity test**

Create `test/integration/locale_parity_test.rb`:

```ruby
require "test_helper"

class LocaleParityTest < ActiveSupport::TestCase
  EN = YAML.load_file(Rails.root.join("config/locales/en.yml"))["en"]

  def flatten_keys(hash, prefix = "")
    hash.flat_map do |k, v|
      key = prefix.empty? ? k.to_s : "#{prefix}.#{k}"
      v.is_a?(Hash) ? flatten_keys(v, key) : [ key ]
    end
  end

  I18n.available_locales.map(&:to_s).reject { |l| l == "en" }.each do |locale|
    test "#{locale} has all new feature keys" do
      data = YAML.load_file(Rails.root.join("config/locales/#{locale}.yml"))[locale]
      en_keys = flatten_keys(EN.slice("favorites", "profile", "bans").merge(
        "settings" => EN["settings"].slice("public_profile", "copy", "copied", "username", "username_hint", "username_help")
      ))
      locale_keys = flatten_keys((data || {}).slice("favorites", "profile", "bans", "settings"))
      missing = en_keys - locale_keys
      assert_empty missing, "#{locale}.yml missing: #{missing.join(', ')}"
    end
  end
end
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bin/rails test test/integration/locale_parity_test.rb`
Expected: FAIL listing the missing keys per locale.

- [ ] **Step 3: Translate the new keys in each locale**

For each of `bg, de, el, es, fr, ja, nl, ru, zh`, add the `favorites:`, `profile:`, `bans:` blocks and the new `settings:` sub-keys, mirroring the structure added to `en.yml` in Tasks 3/6/8/10/11/12. Translate values into the target language (match the quality/tone of existing translations in that file). Keep keys identical to English; translate only values. Interpolation placeholders (`%{date}`, `%{name}`) must be preserved verbatim.

- [ ] **Step 4: Run the test to verify it passes**

Run: `bin/rails test test/integration/locale_parity_test.rb`
Expected: PASS for all locales.

- [ ] **Step 5: Commit**

```bash
git add config/locales/*.yml test/integration/locale_parity_test.rb
git commit -m "Translate favorites, profile and ban strings across locales"
```

---

### Task 14: Full verification and lint

- [ ] **Step 1: Run the full test suite**

Run: `bin/rails test`
Expected: PASS (0 failures, 0 errors).

- [ ] **Step 2: Run rubocop and autocorrect safe offenses**

Run: `bin/rubocop -a`
Expected: no remaining offenses (fix any manually).

- [ ] **Step 3: Run brakeman**

Run: `bin/brakeman --quiet --no-pager`
Expected: no new warnings (the polymorphic `constantize` in `FavoritesController` is constrained by the `FAVORITABLE_TYPES` whitelist; confirm brakeman is satisfied or add a guard comment).

- [ ] **Step 4: Verify seeds still load**

Run: `env RAILS_ENV=test bin/rails db:seed:replant`
Expected: completes without error.

- [ ] **Step 5: Final commit if anything changed**

```bash
git add -A
git commit -m "Lint and verification pass for favorites/profiles/bans"
```

---

## Notes for the implementer

- **Polymorphic safety:** `FavoritesController#set_favoritable` and `Favorite#FAVORITABLE_TYPES` are the only places that `constantize` user input — keep the whitelist authoritative.
- **`@active_ban` memoization:** `User#active_ban` memoizes; in tests that mutate bans on a loaded user, call `user.reload` (the tests above already do).
- **Capability list is the contract:** `Ban::CAPABILITIES` must stay in sync with the `require_contribution(:x)` symbols used across controllers. If you add a new contribution type later, add it to both.
- **Existing patterns to mirror:** `UpvotesController` (toggle idiom), `ModerationItem`/`Claim` (enum + scope style), `admin/dashboard` views (table + `admin/nav` partial), `settings/edit` (form builder + `field` markup).
