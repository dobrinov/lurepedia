class Species < ApplicationRecord
  include Sluggable
  include Favoritable
  include WaterClassified
  include Publishable
  include LocalizedDescriptions
  include Croppable

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

  # Every name this species is known by, for search: contributor local names
  # in all locales, the bundled translations (viewer's locale and English),
  # the key fallback, and the scientific name.
  def searchable_names
    names = (local_names || {}).values
    names << I18n.t("species_names.#{key}.common", default: nil)
    names << I18n.t("species_names.#{key}.common", locale: :en, default: nil)
    names << key.to_s.titleize
    names << scientific_name
    names.compact_blank.uniq
  end

  # True when the query matches any known name — as a substring, or (for
  # queries of 4+ characters) as a word prefix within one typo, two for long
  # queries, so "bara" still finds "Barracuda". Name search happens in Ruby
  # because common names are not stored as a plain column (local_names JSON
  # + bundled translations).
  def name_matches?(query)
    q = query.to_s.downcase.strip
    return false if q.blank?

    searchable_names.any? do |name|
      name = name.downcase
      next true if name.include?(q)
      next false if q.length < 4

      tolerance = q.length >= 8 ? 2 : 1
      name.split(/[^[:alnum:]]+/).any? { |word| self.class.prefix_distance(word, q) <= tolerance }
    end
  end

  # Smallest edit distance between the query and a same-length-ish prefix of
  # the word (one shorter through one longer, so an inserted or dropped letter
  # doesn't shift the whole comparison).
  def self.prefix_distance(word, query)
    (-1..1).map { |d| edit_distance(word[0, [ query.length + d, 0 ].max].to_s, query) }.min
  end

  # Plain Levenshtein distance; inputs are short (query-length) strings.
  def self.edit_distance(a, b)
    prev = (0..b.length).to_a
    a.each_char.with_index(1) do |ca, i|
      curr = [ i ]
      b.each_char.with_index(1) do |cb, j|
        curr << [ prev[j] + 1, curr[j - 1] + 1, prev[j - 1] + (ca == cb ? 0 : 1) ].min
      end
      prev = curr
    end
    prev.last
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
