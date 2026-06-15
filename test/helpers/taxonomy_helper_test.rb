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

  test "unpopulated locale falls back to english" do
    I18n.with_locale(:fr) do
      assert_equal "Largemouth Bass", species_common_name("largemouth_bass")
      assert_equal "Crankbait", lure_type_name("crankbait")
    end
  end

  test "condition names translated" do
    I18n.with_locale(:en) { assert_equal "Clear", condition_name(:clarity, "clear") }
    I18n.with_locale(:bg) { assert_equal "Бистра", condition_name(:clarity, "clear") }
  end

  test "action name handles none" do
    I18n.with_locale(:en) do
      assert_equal "—", action_name("none")
      assert_equal "Suspending", action_name("suspending")
    end
  end
end
