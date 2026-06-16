class Shop < ApplicationRecord
  include Sluggable
  include Favoritable

  has_many :buy_links, dependent: :destroy
  has_many :lures, through: :buy_links
  has_one :claim, as: :claimable, dependent: :destroy
  has_many :revisions, as: :subject, dependent: :destroy

  validates :name, presence: true

  scope :promoted_first, -> { order(promoted: :desc, name: :asc) }
  scope :promoted, -> { where(promoted: true) }
  scope :regular, -> { where(promoted: false) }

  def claimed?
    claimed
  end

  private

  def slug_source
    name
  end
end
