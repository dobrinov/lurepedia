class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :catches, foreign_key: :user_id, dependent: :destroy
  has_many :comments, dependent: :destroy
  has_many :upvotes, dependent: :destroy
  has_many :reports, foreign_key: :user_id, dependent: :destroy

  enum :role, { member: 0, moderator: 1, admin: 2 }, default: :member
  enum :units, { auto: 0, imperial: 1, metric: 2 }, default: :auto, prefix: true

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :name, presence: true

  def initials
    name.to_s.split(/\s+/).map { |w| w[0] }.first(2).join.upcase
  end

  def staff?
    moderator? || admin?
  end

  def can_moderate?
    staff?
  end
end
