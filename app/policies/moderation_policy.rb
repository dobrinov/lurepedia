class ModerationPolicy < ApplicationPolicy
  def index? = moderator?

  # record is a ModerationItem
  def act? = record&.actionable_by?(user)
end
