require "test_helper"

class IdentityTest < ActiveSupport::TestCase
  def auth(email:, uid: "g-123", name: "Riley Angler", provider: "google_oauth2")
    OmniAuth::AuthHash.new(
      provider: provider, uid: uid,
      info: { email: email, name: name }
    )
  end

  test "from_omniauth creates a user and identity for a new person" do
    assert_difference [ "User.count", "Identity.count" ], 1 do
      @user = User.from_omniauth(auth(email: "brand-new@example.com"))
    end

    assert_equal "brand-new@example.com", @user.email_address
    assert_equal "Riley Angler", @user.name
    assert @user.previously_new_record?
    assert @user.identities.exists?(provider: "google_oauth2", uid: "g-123")
  end

  test "from_omniauth links to an existing user with the same email" do
    existing = users(:two)

    assert_no_difference "User.count" do
      assert_difference "Identity.count", 1 do
        @user = User.from_omniauth(auth(email: existing.email_address.upcase))
      end
    end

    assert_equal existing.id, @user.id
    assert_not @user.previously_new_record?
  end

  test "from_omniauth returns the same user for a returning identity" do
    first  = User.from_omniauth(auth(email: "returning@example.com", uid: "g-999"))

    assert_no_difference [ "User.count", "Identity.count" ] do
      @again = User.from_omniauth(auth(email: "returning@example.com", uid: "g-999"))
    end

    assert_equal first.id, @again.id
  end

  test "an oauth user needs no password" do
    user = User.from_omniauth(auth(email: "nopass@example.com"))
    assert user.persisted?
    assert_nil user.password_digest
  end

  test "email/password signup still requires a password" do
    user = User.new(name: "No Password", email_address: "np@example.com", country: "US")
    assert_not user.valid?
    assert_includes user.errors.attribute_names, :password
  end

  test "uid is unique per provider" do
    User.from_omniauth(auth(email: "a@example.com", uid: "dup"))
    dup = Identity.new(provider: "google_oauth2", uid: "dup", user: users(:one))
    assert_not dup.valid?
  end
end
