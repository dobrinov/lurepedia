class Claim < ApplicationRecord
  belongs_to :claimable, polymorphic: true
  belongs_to :user

  enum :status, { pending: 0, verified: 1, rejected: 2 }, prefix: true

  validates :email, presence: true
  validates :message, presence: true

  def kind
    claimable_type.to_s.downcase
  end

  # Ownership is vetted by hand: the claimant leaves an email and explains who
  # they are, and an admin settles it over email before deciding in the
  # moderation queue. The claimable's #claimed? derives from this status.
  def approve!
    update!(status: :verified)
  end

  def reject!
    update!(status: :rejected)
  end

  def reopen!
    update!(status: :pending)
  end
end
