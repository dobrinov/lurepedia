class User < ApplicationRecord
  include Sluggable

  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :catches, foreign_key: :user_id, dependent: :destroy
  has_many :comments, dependent: :destroy
  has_many :upvotes, dependent: :destroy
  has_many :reports, foreign_key: :user_id, dependent: :destroy
  has_many :favorites, dependent: :destroy
  has_many :bans, dependent: :destroy

  enum :role, { member: 0, moderator: 1, admin: 2 }, default: :member
  enum :length_units, { auto: 0, imperial: 1, metric: 2 }, default: :auto, prefix: :length
  enum :weight_units, { auto: 0, imperial: 1, metric: 2 }, default: :auto, prefix: :weight
  enum :depth_units, { auto: 0, imperial: 1, metric: 2 }, default: :auto, prefix: :depth

  normalizes :email_address, with: ->(e) { e.strip.downcase }
  normalizes :username, with: ->(u) { u.to_s.strip.downcase.presence }

  validates :name, presence: true
  validates :username, uniqueness: { case_sensitive: false },
                       format: { with: /\A[a-z0-9_-]{3,30}\z/ },
                       allow_nil: true
  validate :username_not_taken_as_slug

  def self.find_by_handle!(handle)
    (handle.present? && find_by(username: handle)) || find_by!(slug: handle)
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
end
