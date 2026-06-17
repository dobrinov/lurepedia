class Species < ApplicationRecord
  include Sluggable
  include Favoritable

  self.table_name = "species"

  has_many :catches, dependent: :destroy
  has_many :revisions, as: :subject, dependent: :destroy
  has_one_attached :photo

  enum :water, { fresh: 0, salt: 1, both: 2 }, prefix: :water

  validates :key, presence: true, uniqueness: true
  validates :wikipedia_url,
            format: { with: %r{\Ahttps://[a-z]{2,}\.(m\.)?wikipedia\.org/wiki/.+\z}i, message: ->(*) { I18n.t("species.wikipedia_url_invalid") } },
            allow_blank: true

  scope :alpha, -> { order(:key) }
  scope :proven, -> { where("catches_count > 0") }

  def common_name
    I18n.t("species_names.#{key}.common", default: key.to_s.titleize)
  end

  def habitat
    I18n.t("species_names.#{key}.habitat", default: "")
  end

  # Distinct lures proven to catch this species.
  def proven_lures
    Lure.joins(variants: :catches).where(catches: { species_id: id }).distinct
  end

  private

  def slug_source
    common_name.presence || key
  end
end
