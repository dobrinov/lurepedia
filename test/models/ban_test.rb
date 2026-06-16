require "test_helper"

class BanTest < ActiveSupport::TestCase
  def setup
    @user = users(:two)
    @admin = users(:one)
  end

  def ban(**attrs)
    Ban.create!({ user: @user, issued_by: @admin, reason: "spam", capabilities: %w[catalog] }.merge(attrs))
  end

  test "requires a reason" do
    b = Ban.new(user: @user, issued_by: @admin, capabilities: %w[catalog])
    assert_not b.valid?
  end

  test "capabilities must be a subset of CAPABILITIES" do
    b = Ban.new(user: @user, issued_by: @admin, reason: "x", capabilities: %w[bogus])
    assert_not b.valid?
  end

  test "active scope excludes revoked and expired bans" do
    active = ban
    ban(revoked_at: Time.current)
    ban(expires_at: 1.day.ago)
    assert_equal [ active ], Ban.active.to_a
  end

  test "active? reflects revoked and expiry state" do
    assert ban.active?
    assert_not ban(revoked_at: Time.current).active?
    assert_not ban(expires_at: 1.hour.ago).active?
    assert ban(expires_at: 1.hour.from_now).active?
  end

  test "permanent? when no expiry" do
    assert ban.permanent?
    assert_not ban(expires_at: 1.day.from_now).permanent?
  end

  test "blocks? checks capability membership" do
    b = ban(capabilities: %w[catalog catches])
    assert b.blocks?(:catches)
    assert_not b.blocks?(:comments)
  end

  test "user active_ban and blocked_from?" do
    assert_nil @user.active_ban
    ban(capabilities: %w[catches])
    @user.reload
    assert @user.active_ban
    assert @user.blocked_from?(:catches)
    assert_not @user.blocked_from?(:comments)
  end

  test "presets expose capability sets" do
    assert_equal %w[catalog claims], Ban::PRESETS["catalog_only"]
    assert Ban::PRESETS.key?("full")
  end
end
