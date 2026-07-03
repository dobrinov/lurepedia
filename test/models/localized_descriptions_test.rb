require "test_helper"

# LocalizedDescriptions behavior on Brand and Lure (Species is covered by
# SpeciesDescriptionTest).
class LocalizedDescriptionsTest < ActiveSupport::TestCase
  test "brand description prefers the viewer's locale, then English, then nothing" do
    brand = Brand.create!(name: "Desc Baits",
                          local_descriptions: { "en" => "Hand-poured plastics.", "bg" => "Ръчно лети примамки." })

    I18n.with_locale(:bg) { assert_equal "Ръчно лети примамки.", brand.description }
    I18n.with_locale(:en) { assert_equal "Hand-poured plastics.", brand.description }
    I18n.with_locale(:de) { assert_equal "Hand-poured plastics.", brand.description } # no de description -> en
    brand.local_descriptions = { "bg" => "Ръчно лети примамки." }
    I18n.with_locale(:de) { assert_nil brand.description }
  end

  test "lure description falls back to English and drops blank values on assignment" do
    brand = Brand.create!(name: "Desc Tackle")
    type = LureType.create!(key: "crankbait")
    lure = Lure.create!(brand: brand, lure_type: type, model: "Wobbler",
                        local_descriptions: { "en" => "A tight-wiggling crank.", "ja" => "   " })

    assert_equal({ "en" => "A tight-wiggling crank." }, lure.local_descriptions, "blank values dropped")
    I18n.with_locale(:ja) { assert_equal "A tight-wiggling crank.", lure.description }
  end
end
