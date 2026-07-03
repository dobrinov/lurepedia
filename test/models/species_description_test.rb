require "test_helper"

class SpeciesDescriptionTest < ActiveSupport::TestCase
  test "description prefers the viewer's locale, then English, then nothing" do
    s = Species.create!(key: "desc_bass", scientific_name: "Desc bass", water: :fresh,
                        local_descriptions: { "en" => "A popular gamefish.", "es" => "Un pez deportivo popular." })

    I18n.with_locale(:es) { assert_equal "Un pez deportivo popular.", s.description }
    I18n.with_locale(:en) { assert_equal "A popular gamefish.", s.description }
    I18n.with_locale(:de) { assert_equal "A popular gamefish.", s.description } # no de description -> en
  end

  test "description is nil when neither the locale nor English is available" do
    s = Species.create!(key: "desc_perch", scientific_name: "Desc perch", water: :fresh,
                        local_descriptions: { "bg" => "Хищна риба." })

    I18n.with_locale(:bg) { assert_equal "Хищна риба.", s.description }
    I18n.with_locale(:de) { assert_nil s.description }
  end

  test "blank descriptions are dropped on assignment" do
    s = Species.create!(key: "desc_pike", scientific_name: "Desc pike", water: :fresh,
                        local_descriptions: { "en" => "Ambush predator.", "fr" => "   " })
    assert_equal({ "en" => "Ambush predator." }, s.local_descriptions)
  end
end
