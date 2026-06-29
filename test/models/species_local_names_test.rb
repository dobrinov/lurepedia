require "test_helper"

class SpeciesLocalNamesTest < ActiveSupport::TestCase
  test "common_name prefers the viewer's locale, then English, then the key" do
    s = Species.create!(key: "ln_bass", scientific_name: "LN bass", water: :fresh,
                        local_names: { "en" => "Largemouth Bass", "es" => "Lobina negra" })

    I18n.with_locale(:es) { assert_equal "Lobina negra", s.common_name }
    I18n.with_locale(:en) { assert_equal "Largemouth Bass", s.common_name }
    I18n.with_locale(:de) { assert_equal "Largemouth Bass", s.common_name } # no de name -> en
  end

  test "blank local names are dropped on assignment" do
    s = Species.create!(key: "ln_perch", scientific_name: "LN perch", water: :fresh,
                        local_names: { "en" => "Perch", "es" => "   " })
    assert_equal({ "en" => "Perch" }, s.local_names)
  end

  test "falls back to the humanized key when no name is set" do
    s = Species.create!(key: "ln_unknown_fish", scientific_name: "LN unknown", water: :fresh)
    assert_equal "Ln Unknown Fish", s.common_name
  end
end
