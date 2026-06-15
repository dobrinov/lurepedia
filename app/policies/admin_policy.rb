class AdminPolicy < ApplicationPolicy
  def access? = admin?
  def manage_roles? = admin?
end
