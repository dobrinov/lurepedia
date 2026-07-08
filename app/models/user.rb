class User < ApplicationRecord
  include Sluggable

  # Password is optional: OAuth-only users have no password_digest. We keep the
  # has_secure_password attribute methods (password=, authenticate, authenticate_by)
  # but skip its validations and enforce presence ourselves only for the
  # email/password signup path (see below).
  has_secure_password validations: false
  has_one_attached :avatar
  has_many :identities, dependent: :destroy
  has_many :sessions, dependent: :destroy
  has_many :catches, foreign_key: :user_id, dependent: :destroy
  has_many :comments, dependent: :destroy
  has_many :upvotes, dependent: :destroy
  has_many :reports, foreign_key: :user_id, dependent: :destroy
  has_many :favorites, dependent: :destroy
  has_many :bans, dependent: :destroy
  has_many :revisions, dependent: :nullify
  has_many :claims, dependent: :destroy

  enum :role, { member: 0, moderator: 1, admin: 2 }, default: :member
  enum :length_units, { auto: 0, imperial: 1, metric: 2 }, default: :auto, prefix: :length
  enum :weight_units, { auto: 0, imperial: 1, metric: 2 }, default: :auto, prefix: :weight
  enum :depth_units, { auto: 0, imperial: 1, metric: 2 }, default: :auto, prefix: :depth

  normalizes :email_address, with: ->(e) { e.strip.downcase }
  normalizes :username, with: ->(u) { u.to_s.strip.downcase.presence }

  validates :name, presence: true
  validates :password, length: { maximum: 72 }, confirmation: true, allow_blank: true
  validates :password, presence: true, on: :create, unless: :oauth_signup?
  # Setting/changing a password from the settings page (see SettingsController#password),
  # where presence is required regardless of how the account was created.
  validates :password, presence: true, on: :password_update
  validates :time_zone, inclusion: { in: ->(*) { ActiveSupport::TimeZone.all.map(&:name) } }, allow_blank: true
  validates :username, uniqueness: { case_sensitive: false },
                       format: { with: /\A[a-z0-9_-]{3,30}\z/ },
                       allow_nil: true
  validate :username_not_taken_as_slug
  validate :acceptable_avatar

  AVATAR_TYPES = %w[ image/png image/jpeg image/webp image/gif ].freeze
  AVATAR_MAX_SIZE = 5.megabytes

  def self.find_by_handle!(handle)
    (handle.present? && find_by(username: handle)) || find_by!(slug: handle)
  end

  # Resolve (or create) the user behind an OmniAuth payload. Accounts are linked
  # by verified email: an existing identity wins, else a user with the same email
  # gets the new identity attached, else a fresh user is created. Providers we
  # enable (Google, later Apple) return verified emails, so this is safe.
  def self.from_omniauth(auth)
    Identity.find_by(provider: auth.provider, uid: auth.uid)&.user ||
      link_or_create_from_omniauth(auth)
  end

  def self.link_or_create_from_omniauth(auth)
    email = auth.info.email.to_s.strip.downcase
    user  = (email.present? && find_by(email_address: email)) || new_from_omniauth(auth, email)
    user.identities.build(provider: auth.provider, uid: auth.uid)
    user.oauth_signup = true
    user.save!
    user
  end

  def self.new_from_omniauth(auth, email)
    new(
      email_address: email,
      name: auth.info.name.presence || email.split("@").first.presence || "Angler",
      country: "US",
      locale: I18n.locale.to_s
    )
  end

  def to_param
    username.presence || slug
  end

  def initials
    name.to_s.split(/\s+/).map { |w| w[0] }.first(2).join.upcase
  end

  def staff?
    moderator? || admin?
  end

  # Whether this account can sign in with an email/password (OAuth-only users
  # have no digest until they set one from settings).
  def password_set?
    password_digest.present?
  end

  # Set when a record is being created through OmniAuth so password presence is
  # not required. A record that already has identities is likewise OAuth-backed.
  attr_accessor :oauth_signup

  def oauth_signup?
    oauth_signup || identities.any?
  end

  # Brand ids this user owns through a verified claim — submissions to these
  # brands skip review (see Editable#can_add_directly?).
  def owned_brand_ids
    claims.where(status: :verified, claimable_type: "Brand").pluck(:claimable_id)
  end

  def can_moderate?
    staff?
  end

  def active_ban
    @active_ban ||= bans.active.newest_first.first
  end

  def blocked_from?(capability)
    active_ban&.blocks?(capability) || false
  end

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

  def acceptable_avatar
    return unless avatar.attached?

    unless avatar.blob.byte_size <= AVATAR_MAX_SIZE
      errors.add(:avatar, I18n.t("settings.avatar_too_large"))
    end

    unless AVATAR_TYPES.include?(avatar.blob.content_type)
      errors.add(:avatar, I18n.t("settings.avatar_invalid_type"))
    end
  end
end
