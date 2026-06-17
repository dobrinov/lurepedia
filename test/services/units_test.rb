require "test_helper"

class UnitsTest < ActiveSupport::TestCase
  test "length formatting" do
    assert_equal "21.5 in", Units.format_length(54.6, :imperial)
    assert_equal "54.6 cm", Units.format_length(54.6, :metric)
  end

  test "weight formatting imperial uses lb then oz" do
    assert_equal "5.2 lb", Units.format_weight(2359, :imperial)
    assert_equal "12 oz", Units.format_weight(340, :imperial)
  end

  test "weight formatting metric uses g then kg" do
    assert_equal "2.4 kg", Units.format_weight(2359, :metric)
    assert_equal "340 g", Units.format_weight(340, :metric)
  end

  test "depth range formatting" do
    assert_equal "3–5 ft", Units.format_depth(91, 152, :imperial)
    assert_equal "0.9–1.5 m", Units.format_depth(91, 152, :metric)
  end

  test "auto resolves from country, not language" do
    assert_equal :imperial, Units.system(:auto, country: "US")
    assert_equal :metric, Units.system(:auto, country: "DE")
    assert_equal :metric, Units.system(:auto, country: "GB")
    assert_equal :metric, Units.system(:auto, country: "JP")
    assert_equal :metric, Units.system(:auto, country: nil)
  end

  test "country matching is case-insensitive" do
    assert_equal :imperial, Units.system(:auto, country: "us")
  end

  test "explicit setting overrides country" do
    assert_equal :metric, Units.system(:metric, country: "US")
    assert_equal :imperial, Units.system(:imperial, country: "DE")
  end

  test "auto applies per measurement against country" do
    assert_equal "21.5 in", Units.format_length(54.6, :auto, country: "US")
    assert_equal "54.6 cm", Units.format_length(54.6, :auto, country: "DE")
  end
end
