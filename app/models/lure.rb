class Lure < ApplicationRecord
  include Sluggable
  include Favoritable

  belongs_to :brand, counter_cache: :lures_count
  belongs_to :lure_type
  belongs_to :default_variant, class_name: "Variant", optional: true
  has_many :variants, dependent: :destroy
  has_many :builds, dependent: :destroy
  has_many :catches, through: :variants
  has_many :buy_links, dependent: :destroy
  has_many :shops, through: :buy_links
  has_one :claim, as: :claimable, dependent: :destroy
  has_many :revisions, as: :subject, dependent: :destroy

  validates :model, presence: true

  scope :by_catch_count, -> { order(catches_count: :desc, model: :asc) }
  scope :proven, -> { where("catches_count > 0") }
  scope :unproven, -> { where(catches_count: 0) }

  def proven?
    catches_count.positive?
  end

  # The color shown across catalogs: the explicit pick, else the first-added.
  # Kept distinct from the `default_variant` association (the explicit choice
  # alone, possibly nil) so the association isn't shadowed and stays eager-loadable.
  def primary_variant
    default_variant || variants.order(:id).first
  end

  # Family-wide depth window, spanning every build's range.
  def depth_range
    mins = builds.filter_map(&:depth_min_cm)
    maxes = builds.filter_map(&:depth_max_cm)
    { min_cm: mins.min, max_cm: maxes.max }
  end

  # Water suitability across builds: a single type if uniform, else "both".
  def water_summary
    kinds = builds.map(&:water).uniq
    return "fresh" if kinds.empty?
    return kinds.first if kinds.size == 1

    "both"
  end

  # The most common buoyancy across builds — used for the family-level tag.
  def dominant_action
    actions = builds.filter_map { |b| b.action unless b.action_none? }
    return "none" if actions.empty?

    actions.tally.max_by { |_action, count| count }.first
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
