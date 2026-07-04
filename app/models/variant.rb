class Variant < ApplicationRecord
  include Publishable
  include Croppable

  belongs_to :lure
  has_many :catches, dependent: :destroy
  has_many :variant_builds, dependent: :destroy
  has_many :builds, through: :variant_builds
  has_many :revisions, as: :subject, dependent: :destroy
  has_one_attached :photo

  validates :name, presence: true

  # Whether contributors have confirmed which builds carry this color.
  # Availability is open-world: no rows means unknown, never "available nowhere".
  def availability_known?
    variant_builds.loaded? ? variant_builds.any? : variant_builds.exists?
  end

  # The builds this color is shown with: the confirmed subset, else — open
  # world — every build of the lure.
  def available_builds
    availability_known? ? builds.ordered : lure.builds.ordered
  end

  # Human-readable, shareable identifier used in the lure URL (?color=ghost-shad)
  # in place of the opaque numeric id.
  def to_color_param
    name.parameterize
  end

  # A color is the lure's default when it is explicitly set, or — absent an
  # explicit choice — when it is the first-added color. Mirrors Lure#primary_variant.
  def default?
    lure.primary_variant&.id == id
  end
end
