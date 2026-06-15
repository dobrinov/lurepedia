class Brand < ApplicationRecord
  include Sluggable

  has_many :lures, dependent: :destroy
  has_one :claim, as: :claimable, dependent: :destroy
  has_many :revisions, as: :subject, dependent: :destroy
  has_one_attached :logo

  validates :name, presence: true

  scope :alpha, -> { order(:name) }

  def claimed?
    claimed
  end

  def initials
    name.to_s.split(/\s+/).map { |w| w[0] }.first(2).join.upcase
  end

  private

  def slug_source
    name
  end
end
