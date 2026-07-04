class Catch < ApplicationRecord
  self.table_name = "catches"

  belongs_to :user
  belongs_to :variant, counter_cache: :catches_count
  belongs_to :build, counter_cache: :catches_count, optional: true
  belongs_to :species, counter_cache: :catches_count
  has_one :lure, through: :variant
  has_many :comments, dependent: :destroy
  has_many :upvotes, dependent: :destroy
  has_many :reports, as: :reportable, dependent: :destroy
  has_many :moderation_items, as: :subject, dependent: :destroy
  has_many_attached :photos

  enum :season, { spring: 0, summer: 1, fall: 2, winter: 3 }, prefix: :season
  enum :clarity, { clear: 0, stained: 1, muddy: 2 }, prefix: :clarity
  enum :water_body, { lake: 0, pond: 1, river: 2, reservoir: 3, stream: 4 }, prefix: :water_body
  enum :wind, { calm: 0, light: 1, moderate: 2, strong: 3 }, prefix: :wind
  enum :time_of_day, { dawn: 0, morning: 1, midday: 2, afternoon: 3, dusk: 4, night: 5 }, prefix: :tod
  enum :platform, { shore: 0, boat: 1, kayak: 2 }, prefix: :platform
  enum :retrieve, { steady: 0, stop_and_go: 1, twitch: 2, jerk: 3, slow_roll: 4, burn: 5, dead_stick: 6 }, prefix: :retrieve

  scope :recent, -> { order(created_at: :desc) }

  validate :build_belongs_to_variants_lure

  after_create :bump_lure_counter
  after_destroy :drop_lure_counter

  def contributor
    user
  end

  # Condition values present, as [group, value] pairs for chip rendering.
  def condition_pairs
    {
      season: season, water_body: water_body, platform: platform,
      retrieve: retrieve, clarity: clarity, wind: wind, time_of_day: time_of_day
    }.compact
  end

  def upvoted_by?(some_user)
    return false unless some_user

    upvotes.exists?(user_id: some_user.id)
  end

  private

  # A catch's optional build must belong to the same lure as its color, so the
  # two foreign keys can't describe a configuration that doesn't exist.
  def build_belongs_to_variants_lure
    return if build.nil? || variant.nil?

    errors.add(:build, :invalid) if build.lure_id != variant.lure_id
  end

  def bump_lure_counter
    Lure.where(id: variant.lure_id).update_counters(catches_count: 1)
  end

  def drop_lure_counter
    Lure.where(id: variant.lure_id).update_counters(catches_count: -1)
  end
end
