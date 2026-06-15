require "test_helper"

class PoliciesTest < ActiveSupport::TestCase
  def setup
    @guest = nil
    @member = User.new(role: :member)
    @moderator = User.new(role: :moderator)
    @admin = User.new(role: :admin)
  end

  test "catch creation requires login" do
    assert_not CatchPolicy.new(@guest).create?
    assert CatchPolicy.new(@member).create?
  end

  test "moderation index needs moderator" do
    assert_not ModerationPolicy.new(@member).index?
    assert ModerationPolicy.new(@moderator).index?
    assert ModerationPolicy.new(@admin).index?
  end

  test "moderation act respects item actionability" do
    actionable = Struct.new(:ok) { def actionable_by?(u) = ok }.new(true)
    locked = Struct.new(:ok) { def actionable_by?(u) = ok }.new(false)
    assert ModerationPolicy.new(@moderator, actionable).act?
    assert_not ModerationPolicy.new(@moderator, locked).act?
  end

  test "admin access only for admins" do
    assert_not AdminPolicy.new(@moderator).access?
    assert AdminPolicy.new(@admin).access?
    assert AdminPolicy.new(@admin).manage_roles?
  end
end
