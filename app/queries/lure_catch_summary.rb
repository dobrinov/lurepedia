# Aggregates a lure's full catch log for the "What the catches show" panel
# on the lure page. The panel renders outside the tabs: tab URLs canonicalize
# to the base lure URL, so anything inside a non-default tab is invisible to
# crawlers — this summary is the page's crawlable catch evidence.
class LureCatchSummary
  CONDITION_GROUPS = %i[season water_body clarity time_of_day wind platform retrieve].freeze

  def initialize(lure)
    @lure = lure
  end

  def any?
    total.positive?
  end

  def total
    @lure.catches_count
  end

  # Most-caught species as [ Species, count ] pairs, most frequent first.
  def species_counts(limit: 4)
    counts = catches.group(:species_id).count.sort_by { |_, n| -n }.first(limit)
    species = Species.where(id: counts.map(&:first)).index_by(&:id)
    counts.map { |id, n| [ species[id], n ] }
  end

  # { season: [ [ "spring", 6 ], ... ], ... } — top values per condition
  # group, most frequent first; groups nobody has logged are omitted.
  def condition_counts(per_group: 3)
    CONDITION_GROUPS.each_with_object({}) do |group, out|
      top = catches.where.not(group => nil).group(group).count.sort_by { |_, n| -n }.first(per_group)
      out[group] = top if top.any?
    end
  end

  private

  def catches
    @lure.catches
  end
end
