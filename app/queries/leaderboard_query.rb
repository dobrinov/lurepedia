# Ranks anglers by a chosen metric, optionally scoped to one species.
class LeaderboardQuery
  Row = Struct.new(:user, :catches, :upvotes, :best_length_cm, :species_count, keyword_init: true)

  METRICS = %i[catches upvotes length].freeze

  def initialize(species: nil, metric: :catches)
    @species = species
    @metric = METRICS.include?(metric.to_sym) ? metric.to_sym : :catches
  end

  attr_reader :metric

  def rows
    scope = Catch.all
    scope = scope.where(species_id: @species.id) if @species

    grouped = scope.includes(:user).group_by(&:user)

    rows = grouped.map do |user, catches|
      Row.new(
        user: user,
        catches: catches.size,
        upvotes: catches.sum(&:upvotes_count),
        best_length_cm: catches.filter_map(&:length_cm).max,
        species_count: catches.map(&:species_id).uniq.size
      )
    end

    rows.sort_by { |r| [-sort_value(r), -r.upvotes, r.user.name] }
  end

  private

  def sort_value(row)
    case @metric
    when :upvotes then row.upvotes
    when :length then row.best_length_cm.to_f
    else row.catches
    end
  end
end
