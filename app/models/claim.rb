class Claim < ApplicationRecord
  belongs_to :claimable, polymorphic: true
  belongs_to :user

  enum :status, { pending: 0, verified: 1, rejected: 2 }, prefix: true

  before_validation :generate_token, on: :create
  validates :verification_token, presence: true

  def kind
    claimable_type.to_s.downcase
  end

  def txt_record
    verification_token
  end

  # Simulated DNS-TXT verification: in production this would query DNS for the
  # token. Here we trust the stored token and mark ownership verified.
  def verify!
    update!(status: :verified, dns_verified_at: Time.current)
    claimable.update!(claimed: true) if claimable.respond_to?(:claimed)
  end

  private

  def generate_token
    return if verification_token.present?

    hex = SecureRandom.hex(3)
    slug = claimable.try(:slug) || claimable_id
    self.verification_token = "lurepedia-verify=lp_#{kind}_#{slug}_#{hex}"
  end
end
