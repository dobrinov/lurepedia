class Ban < ApplicationRecord
  belongs_to :user
  belongs_to :issued_by, class_name: "User"
  belongs_to :revoked_by, class_name: "User", optional: true

  CAPABILITIES = %w[catalog claims catches comments upvotes reports favorites].freeze
  PRESETS = {
    "catalog_only"  => %w[catalog claims],
    "contributions" => %w[catalog claims catches comments reports],
    "full"          => %w[catalog claims catches comments reports upvotes favorites]
  }.freeze

  validates :reason, presence: true
  validate :capabilities_present
  validate :capabilities_subset

  scope :active, -> { where(revoked_at: nil).where("expires_at IS NULL OR expires_at > ?", Time.current) }
  scope :newest_first, -> { order(created_at: :desc) }

  def active?
    revoked_at.nil? && (expires_at.nil? || expires_at.future?)
  end

  def permanent?
    expires_at.nil?
  end

  def blocks?(capability)
    capabilities.include?(capability.to_s)
  end

  private

  def capabilities_present
    errors.add(:capabilities, :blank) if Array(capabilities).reject(&:blank?).empty?
  end

  def capabilities_subset
    extra = Array(capabilities).map(&:to_s) - CAPABILITIES
    errors.add(:capabilities, :invalid) if extra.any?
  end
end
