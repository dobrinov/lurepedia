require "test_helper"

class FlagsHelperTest < ActionView::TestCase
  include FlagsHelper

  test "flag emoji from country code" do
    assert_equal "🇺🇸", flag_emoji("US")
    assert_equal "🇯🇵", flag_emoji("jp")
    assert_equal "🇧🇬", flag_emoji("BG")
  end

  test "invalid code yields white flag" do
    assert_equal "🏳️", flag_emoji("ZZZ")
  end

  test "country_flag renders a round span" do
    html = country_flag("DE", size: 20)
    assert_includes html, "border-radius:999px"
    assert_includes html, "🇩🇪"
  end
end
