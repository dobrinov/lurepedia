class Report < ApplicationRecord
  belongs_to :reportable, polymorphic: true
  belongs_to :user

  enum :reason, {
    inaccurate: 0, fake: 1, wrong: 2, spam: 3, offensive: 4, other: 5
  }, prefix: true

  validates :reason, presence: true
end
