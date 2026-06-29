class Species < ApplicationRecord
  include Sluggable
  include Favoritable
  include WaterClassified
  include Publishable

  self.table_name = "species"

  has_many :catches, dependent: :destroy
  has_many :revisions, as: :subject, dependent: :destroy
  has_one_attached :photo

  water_enum

  validates :key, presence: true, uniqueness: true
  validates :wikipedia_url,
            format: { with: %r{\Ahttps://[a-z]{2,}\.(m\.)?wikipedia\.org/wiki/.+\z}i, message: ->(*) { I18n.t("species.wikipedia_url_invalid") } },
            allow_blank: true

  scope :alpha, -> { order(:key) }
  scope :proven, -> { where("catches_count > 0") }

  # Contributor-supplied common names keyed by locale. Stored compacted so a
  # blank field never shadows a fallback.
  def local_names=(value)
    super((value || {}).to_h.transform_values { |v| v.to_s.strip }.reject { |_, v| v.blank? })
  end

  # The display name in the viewer's locale: a contributor's local name first,
  # then their English one, then the bundled translation, then the key.
  def common_name
    names = local_names || {}
    names[I18n.locale.to_s].presence ||
      names["en"].presence ||
      I18n.t("species_names.#{key}.common", default: nil).presence ||
      key.to_s.titleize
  end

  def habitat
    I18n.t("species_names.#{key}.habitat", default: "")
  end

  # Distinct lures proven to catch this species.
  def proven_lures
    Lure.joins(variants: :catches).where(catches: { species_id: id }).distinct
  end

  def proven_lures_count
    proven_lures.count
  end

  # { species_id => distinct proven-lure count } for a set of species, in one
  # query — lets listing pages show the count without an N+1 or a stored column.
  def self.proven_lure_counts(species)
    ids = Array(species).map(&:id)
    return {} if ids.empty?

    Catch.joins(:variant).where(species_id: ids).group(:species_id).distinct.count("variants.lure_id")
  end

  private

  def slug_source
    common_name.presence || key
  end
end
