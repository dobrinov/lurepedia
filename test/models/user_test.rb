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

  test "generates a slug with an opaque token from the name" do
    user = User.create!(name: "Casey Rivera", email_address: "slugtest@example.com", password: "secret123")
    assert_match(/\Acasey-rivera-[a-z0-9]{4}\z/, user.slug)
  end

  test "to_param prefers username over slug" do
    user = User.create!(name: "Dana Powell", email_address: "dana@example.com", password: "secret123")
    assert_equal user.slug, user.to_param
    user.update!(username: "danap")
    assert_equal "danap", user.to_param
  end

  test "find_by_handle! resolves by username or slug" do
    user = User.create!(name: "Kenji Watanabe", email_address: "kenji@example.com", password: "secret123", username: "kenji")
    assert_equal user, User.find_by_handle!("kenji")
    assert_equal user, User.find_by_handle!(user.slug)
    assert_raises(ActiveRecord::RecordNotFound) { User.find_by_handle!("nope") }
  end

  test "find_by_handle! raises on a nil or blank handle" do
    User.create!(name: "Ima User", email_address: "ima@example.com", password: "secret123")
    assert_raises(ActiveRecord::RecordNotFound) { User.find_by_handle!(nil) }
    assert_raises(ActiveRecord::RecordNotFound) { User.find_by_handle!("") }
  end

  test "username is downcased, unique, and format-validated" do
    User.create!(name: "A", email_address: "a@example.com", password: "secret123", username: "Taken")
    dup = User.new(name: "B", email_address: "b@example.com", password: "secret123", username: "TAKEN")
    assert_not dup.valid?

    bad = User.new(name: "C", email_address: "c@example.com", password: "secret123", username: "no spaces!")
    assert_not bad.valid?
  end

  test "username cannot collide with another user's slug" do
    other = User.create!(name: "Maria Rossi", email_address: "maria@example.com", password: "secret123")
    clash = User.new(name: "X", email_address: "x@example.com", password: "secret123", username: other.slug)
    assert_not clash.valid?
  end
end
