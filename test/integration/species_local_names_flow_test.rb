require "test_helper"

# Editing a species through the form persists its per-locale local names.
class SpeciesLocalNamesFlowTest < ActionDispatch::IntegrationTest
  test "an admin can add local names to an existing species via the edit form" do
    species = Species.create!(key: "epinephelus_costae", scientific_name: "Epinephelus costae", water: :salt)
    assert_empty species.local_names

    sign_in_as(users(:one)) # admin -> direct edit, no review
    patch species_path(species, locale: :en),
          params: { species: { local_names: { "en" => "Goldblotch grouper", "fr" => "Mérou badèche", "de" => "" } } }

    species.reload
    assert_equal({ "en" => "Goldblotch grouper", "fr" => "Mérou badèche" }, species.local_names, "blank names dropped, others saved")
    I18n.with_locale(:en) { assert_equal "Goldblotch grouper", species.common_name }
    I18n.with_locale(:fr) { assert_equal "Mérou badèche", species.common_name }
    I18n.with_locale(:de) { assert_equal "Goldblotch grouper", species.common_name } # no de name -> en
  end

  test "an admin can add localised descriptions via the edit form" do
    species = Species.create!(key: "sparus_aurata", scientific_name: "Sparus aurata", water: :salt)
    assert_empty species.local_descriptions

    sign_in_as(users(:one)) # admin -> direct edit, no review
    patch species_path(species, locale: :en),
          params: { species: { local_descriptions: { "en" => "A prized coastal fish.", "fr" => "Un poisson côtier prisé.", "de" => "" } } }

    species.reload
    assert_equal({ "en" => "A prized coastal fish.", "fr" => "Un poisson côtier prisé." }, species.local_descriptions, "blank descriptions dropped, others saved")
    I18n.with_locale(:fr) { assert_equal "Un poisson côtier prisé.", species.description }
    I18n.with_locale(:de) { assert_equal "A prized coastal fish.", species.description } # no de description -> en
  end
end
