class Shop < ApplicationRecord
  include Sluggable
  include Favoritable
  include Publishable

  has_many :buy_links, dependent: :destroy
  has_many :lures, through: :buy_links
  has_one :claim, as: :claimable, dependent: :destroy
  has_many :revisions, as: :subject, dependent: :destroy

  validates :name, presence: true
  validates :url, presence: true

  scope :promoted_first, -> { order(promoted: :desc, name: :asc) }
  scope :promoted, -> { where(promoted: true) }
  scope :regular, -> { where(promoted: false) }

  # Claimed means a verified ownership claim exists (single source of truth).
  def claimed?
    claim&.status_verified? || false
  end

  # The shop's verified owner manages it: their edits skip moderation.
  def managed_by?(user)
    return false unless user

    claim&.status_verified? && claim.user_id == user.id || false
  end

  # Country codes (uppercased) this shop ships to, parsed from the
  # comma-separated `ships_to` string.
  def ships_to_countries
    ships_to.to_s.split(",").map { |c| c.strip.upcase }.reject(&:blank?)
  end

  # Whether the shop delivers to the given ISO country code.
  def ships_to_country?(code)
    ships_worldwide? || ships_to_countries.include?(code.to_s.upcase)
  end

  private

  def slug_source
    name
  end
end
