class LureType < ApplicationRecord
  include WaterClassified

  has_many :lures, dependent: :restrict_with_error

  water_enum(:water_default)

  validates :key, presence: true, uniqueness: true

  # Display name resolved through I18n taxonomy (falls back to en).
  def name
    I18n.t("lure_type.#{key}", default: key.to_s.titleize)
  end

  def to_param
    key
  end
end
