# Minimal plain-Ruby policy layer (no gem). Each policy is constructed with the
# acting user (may be nil) and the record/class being acted on.
class ApplicationPolicy
  attr_reader :user, :record

  def initialize(user, record = nil)
    @user = user
    @record = record
  end

  def signed_in?
    user.present?
  end

  def moderator?
    user&.can_moderate?
  end

  def admin?
    user&.admin?
  end

  # Defaults: reading is public, writing needs a login.
  def index? = true
  def show? = true
  def create? = signed_in?
  def update? = signed_in?
  def destroy? = signed_in?
end
