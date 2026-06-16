module DesignSystem
  # Builds in-memory sample objects so the styleguide can render the real shared
  # partials without touching the database. Each object stubs only the few
  # methods its partial needs — route params (to_param) and associations
  # (proven_species, revisions, lure) — so the production partials render
  # unchanged.
  class SampleData
    Row = Struct.new(:user, :catches, :upvotes, :best_length_cm, keyword_init: true)

    def proven_lure
      @proven_lure ||= build_lure(
        model: "KVD 1.5 Squarebill", brand: "Strike King", type: "crankbait",
        action: :floating, depth_min: 30, depth_max: 120, catches_count: 14,
        species: %w[largemouth_bass smallmouth_bass]
      )
    end

    def unproven_lure
      @unproven_lure ||= build_lure(
        model: "Vision 110", brand: "Megabass", type: "jerkbait",
        action: :suspending, depth_min: 100, depth_max: 180, catches_count: 0,
        species: []
      )
    end

    def sample_catch
      @sample_catch ||= build_catch
    end

    def leaderboard_rows
      [
        Row.new(user: user("Ava Lindqvist", "SE"), catches: 42, upvotes: 318, best_length_cm: 61),
        Row.new(user: user("Diego Marín", "ES"), catches: 37, upvotes: 295, best_length_cm: 58),
        Row.new(user: user("Kenji Watanabe", "JP"), catches: 31, upvotes: 240, best_length_cm: 55),
        Row.new(user: user("Maria Rossi", "IT"), catches: 24, upvotes: 180, best_length_cm: nil)
      ]
    end

    # The provenance panel takes any object responding to :revisions / :claim.
    def provenance_subject
      proven_lure
    end

    private

    def build_lure(model:, brand:, type:, action:, depth_min:, depth_max:, catches_count:, species:)
      lure = Lure.new(model: model, action: action, depth_min_cm: depth_min,
                      depth_max_cm: depth_max, catches_count: catches_count)
      lure.brand = Brand.new(name: brand, slug: brand.parameterize)
      lure.lure_type = LureType.new(key: type)

      proven = species.map { |k| Species.new(key: k) }
      proven.define_singleton_method(:limit) { |n| first(n) }

      revs = sample_revisions
      lure.define_singleton_method(:to_param) { model.parameterize }
      lure.define_singleton_method(:proven_species) { proven }
      lure.define_singleton_method(:claim) { nil }
      lure.define_singleton_method(:revisions) { revs }
      lure
    end

    def build_catch
      catch = Catch.new(season: :summer, clarity: :stained, water_body: :lake,
                        wind: :light, upvotes_count: 23, length_cm: 47)
      catch.species = Species.new(key: "largemouth_bass")
      catch.user = user("Ava Lindqvist", "SE")
      lure = proven_lure
      catch.define_singleton_method(:to_param) { "sample-catch" }
      catch.define_singleton_method(:lure) { lure }
      catch
    end

    def sample_revisions
      base = Time.current
      revs = [
        Revision.new(summary: "Created lure", user: user("Ava Lindqvist", "SE"), created_at: base - 40.days),
        Revision.new(summary: "Added target depth and action", user: user("Diego Marín", "ES"), created_at: base - 12.days),
        Revision.new(summary: "Linked a buy option", user: user("Kenji Watanabe", "JP"), created_at: base - 2.days)
      ]
      revs.define_singleton_method(:newest_first) { sort_by(&:created_at).reverse }
      revs.define_singleton_method(:chronological) { sort_by(&:created_at) }
      revs
    end

    def user(name, country)
      User.new(name: name, country: country, email_address: "#{name.parameterize}@example.com")
    end
  end
end
