class Lure < ApplicationRecord
  include Sluggable

  belongs_to :brand, counter_cache: :lures_count
  belongs_to :lure_type
  has_many :variants, dependent: :destroy
  has_many :catches, through: :variants
  has_many :buy_links, dependent: :destroy
  has_many :shops, through: :buy_links
  has_one :claim, as: :claimable, dependent: :destroy
  has_many :revisions, as: :subject, dependent: :destroy

  enum :water, { fresh: 0, salt: 1, both: 2 }, prefix: :water
  enum :action, { none: 0, suspending: 1, floating: 2, sinking: 3 }, prefix: :action

  validates :model, presence: true

  scope :by_catch_count, -> { order(catches_count: :desc, model: :asc) }
  scope :proven, -> { where("catches_count > 0") }
  scope :unproven, -> { where(catches_count: 0) }

  def proven?
    catches_count.positive?
  end

  def depth_range
    { min_cm: depth_min_cm, max_cm: depth_max_cm }
  end

  # Distinct species this lure has caught.
  def proven_species
    Species.joins(catches: :variant).where(variants: { lure_id: id }).distinct
  end

  def title
    "#{brand.name} #{model}"
  end

  private

  def slug_source
    [ brand&.name, model ].compact.join(" ")
  end
end
