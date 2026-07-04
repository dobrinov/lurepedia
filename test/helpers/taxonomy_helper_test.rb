require "test_helper"

class TaxonomyHelperTest < ActionView::TestCase
  include TaxonomyHelper

  test "species common name translated per locale" do
    I18n.with_locale(:en) { assert_equal "Largemouth Bass", species_common_name("largemouth_bass") }
    I18n.with_locale(:de) { assert_equal "Forellenbarsch", species_common_name("largemouth_bass") }
    I18n.with_locale(:ja) { assert_equal "ラージマウスバス", species_common_name("largemouth_bass") }
    I18n.with_locale(:bg) { assert_equal "Голямоуст костур", species_common_name("largemouth_bass") }
  end

  test "lure type name translated" do
    I18n.with_locale(:en) { assert_equal "Crankbait", lure_type_name("crankbait") }
    I18n.with_locale(:de) { assert_equal "Wobbler", lure_type_name("crankbait") }
  end

  test "formerly stubbed locales are translated" do
    I18n.with_locale(:fr) { assert_equal "Black-bass à grande bouche", species_common_name("largemouth_bass") }
    I18n.with_locale(:ru) { assert_equal "Большеротый окунь", species_common_name("largemouth_bass") }
    I18n.with_locale(:zh) { assert_equal "大口黑鲈", species_common_name("largemouth_bass") }
  end

  test "condition names translated" do
    I18n.with_locale(:en) { assert_equal "Clear", condition_name(:clarity, "clear") }
    I18n.with_locale(:bg) { assert_equal "Бистра", condition_name(:clarity, "clear") }
  end

  test "action name handles none" do
    I18n.with_locale(:en) do
      assert_equal "—", lure_action_label("none")
      assert_equal "Suspending", lure_action_label("suspending")
    end
  end
end
