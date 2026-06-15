require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "downcases and strips email_address" do
    user = User.new(email_address: " DOWNCASED@EXAMPLE.COM ")
    assert_equal("downcased@example.com", user.email_address)
  end

  test "role enum values" do
    assert_equal({ "member" => 0, "moderator" => 1, "admin" => 2 }, User.roles)
  end

  test "units enum values" do
    assert_equal({ "auto" => 0, "imperial" => 1, "metric" => 2 }, User.units)
  end

  test "has secure password" do
    user = User.new(name: "Casey", email_address: "casey@example.com", password: "secret123")
    assert user.authenticate("secret123")
    assert_not user.authenticate("wrong")
  end

  test "requires a name" do
    user = User.new(email_address: "x@example.com", password: "secret123")
    assert_not user.valid?
    assert_includes user.errors[:name], "can't be blank"
  end

  test "initials from name" do
    assert_equal "CR", User.new(name: "Casey Rivera").initials
    assert_equal "M", User.new(name: "Marcus").initials
  end

  test "staff includes moderator and admin" do
    assert User.new(role: :admin).staff?
    assert User.new(role: :moderator).staff?
    assert_not User.new(role: :member).staff?
  end
end
