class Technique < ApplicationRecord
  has_many :lure_techniques, dependent: :destroy
  has_many :lures, through: :lure_techniques

  validates :key, presence: true, uniqueness: true

  # Display name resolved through I18n taxonomy (falls back to en).
  def name
    I18n.t("technique.#{key}", default: key.to_s.titleize)
  end

  def to_param
    key
  end
end
