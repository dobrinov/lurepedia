class CatchPolicy < ApplicationPolicy
  def create? = signed_in?
  def comment? = signed_in?
  def upvote? = signed_in?
  def report? = signed_in?
end
