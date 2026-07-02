require "test_helper"

# Venomous / poisonous hazard flags: set through the edit form, shown as
# warning chips on the species index and show page.
class SpeciesHazardFlagsTest < ActionDispatch::IntegrationTest
  test "an admin can mark a species as venomous via the edit form" do
    species = Species.create!(key: "red_lionfish", scientific_name: "Pterois volitans", water: :salt)

    sign_in_as(users(:one)) # admin -> direct edit, no review
    patch species_path(species, locale: :en),
          params: { species: { venomous: "1", poisonous: "0" } }

    species.reload
    assert species.venomous?
    assert_not species.poisonous?
  end

  test "a member's hazard suggestion is queued with a cast boolean changeset, not applied" do
    species = Species.create!(key: "northern_puffer", scientific_name: "Sphoeroides maculatus", water: :salt)

    sign_in_as(users(:two)) # member -> reviewed suggestion
    assert_difference -> { ModerationItem.count }, 1 do
      patch species_path(species, locale: :en), params: { species: { poisonous: "1" } }
    end

    assert_not species.reload.poisonous?, "suggestions must not mutate the record"
    assert_equal({ "poisonous" => [ false, true ] }, species.revisions.last.changeset)
  end

  test "hazard chips render on the species index and show page" do
    Species.create!(key: "red_lionfish", scientific_name: "Pterois volitans", water: :salt, venomous: true)
    Species.create!(key: "northern_puffer", scientific_name: "Sphoeroides maculatus", water: :salt, poisonous: true)
    harmless = Species.create!(key: "bluegill", scientific_name: "Lepomis macrochirus", water: :fresh)

    get species_index_path(locale: :en)
    assert_select ".tag-danger", text: /#{I18n.t("species.venomous")}/, count: 1
    assert_select ".tag-warn", text: /#{I18n.t("species.poisonous")}/, count: 1

    get species_path(harmless, locale: :en)
    assert_select ".tag-danger", count: 0
    assert_select ".tag-warn", count: 0
  end
end
