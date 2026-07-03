require "test_helper"

# Editing a brand or lure through the form persists its per-locale descriptions.
class LocalizedDescriptionsFlowTest < ActionDispatch::IntegrationTest
  test "an admin can add localised descriptions to a brand via the edit form" do
    brand = Brand.create!(name: "Deps")
    assert_empty brand.local_descriptions

    sign_in_as(users(:one)) # admin -> direct edit, no review
    patch brand_path(brand, locale: :en),
          params: { brand: { local_descriptions: { "en" => "Japanese big-bass specialists.", "de" => "Japanische Big-Bass-Spezialisten.", "bg" => "" } } }

    brand.reload
    assert_equal({ "en" => "Japanese big-bass specialists.", "de" => "Japanische Big-Bass-Spezialisten." }, brand.local_descriptions, "blank descriptions dropped, others saved")
    I18n.with_locale(:de) { assert_equal "Japanische Big-Bass-Spezialisten.", brand.description }
    I18n.with_locale(:fr) { assert_equal "Japanese big-bass specialists.", brand.description } # no fr description -> en
  end

  test "an admin can add localised descriptions to a lure via the edit form" do
    brand = Brand.create!(name: "Jackall")
    type = LureType.create!(key: "swimbait")
    lure = Lure.create!(brand: brand, lure_type: type, model: "Gantarel")
    assert_empty lure.local_descriptions

    sign_in_as(users(:one))
    patch lure_path(lure, locale: :en),
          params: { lure: { local_descriptions: { "en" => "A jointed bluegill swimbait.", "ja" => "ジョイント式ブルーギル型スイムベイト。" } } }

    lure.reload
    assert_equal({ "en" => "A jointed bluegill swimbait.", "ja" => "ジョイント式ブルーギル型スイムベイト。" }, lure.local_descriptions)
    I18n.with_locale(:ja) { assert_equal "ジョイント式ブルーギル型スイムベイト。", lure.description }
    I18n.with_locale(:de) { assert_equal "A jointed bluegill swimbait.", lure.description } # no de description -> en
  end
end
