class Variant < ApplicationRecord
  belongs_to :lure
  has_many :catches, dependent: :destroy
  has_one_attached :photo

  enum :action, { none: 0, suspending: 1, floating: 2, sinking: 3 }, prefix: :action

  validates :name, presence: true

  def effective_action
    action_none? ? lure.action : action
  end
end
