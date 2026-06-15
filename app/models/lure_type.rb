class LureType < ApplicationRecord
  has_many :lures, dependent: :restrict_with_error

  enum :water_default, { fresh: 0, salt: 1, both: 2 }, prefix: :water

  validates :key, presence: true, uniqueness: true

  # Display name resolved through I18n taxonomy (falls back to en).
  def name
    I18n.t("lure_type.#{key}", default: key.to_s.titleize)
  end

  def to_param
    key
  end
end
