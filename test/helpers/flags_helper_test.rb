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

  test "country_flag renders a circular svg when available" do
    html = country_flag("DE", size: 20)
    assert_includes html, "flags/de"
    assert_includes html, "border-radius:999px"
  end

  test "country_flag falls back to emoji span when no svg" do
    html = country_flag("ZZ", size: 20)
    assert_includes html, "border-radius:999px"
    assert_includes html, flag_emoji("ZZ")
  end
end
