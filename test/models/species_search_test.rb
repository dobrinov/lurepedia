require "test_helper"

# Name search: matches any known name (local names in every locale, bundled
# translations, scientific name) and tolerates a typo on queries of 4+ chars.
class SpeciesSearchTest < ActiveSupport::TestCase
  setup do
    @barracuda = Species.new(key: "great_barracuda", scientific_name: "Sphyraena barracuda")
  end

  test "matches a substring of any known name" do
    assert @barracuda.name_matches?("barrac")
    assert @barracuda.name_matches?("sphyraena")
  end

  test "tolerates one typo in a word prefix" do
    assert @barracuda.name_matches?("bara"),     "doubled letter missed"
    assert @barracuda.name_matches?("baracuda"), "dropped letter"
    assert @barracuda.name_matches?("barrqcuda"), "wrong letter"
  end

  test "short queries require an exact substring" do
    assert @barracuda.name_matches?("bar")
    assert_not @barracuda.name_matches?("baa")
  end

  test "does not match unrelated names" do
    walleye = Species.new(key: "walleye", scientific_name: "Sander vitreus")
    assert_not walleye.name_matches?("bara")
    assert_not walleye.name_matches?("pike")
  end

  test "matches contributor local names regardless of the viewer locale" do
    @barracuda.local_names = { "de" => "Pfeilhecht" }
    I18n.with_locale(:en) { assert @barracuda.name_matches?("pfeilhecht") }
  end
end
