require "test_helper"

# A member who isn't an admin or brand owner can suggest a photo, and the upload
# survives the moderation queue: it's persisted at submission time and attached
# to the record when a moderator approves the suggestion.
class PhotoSuggestionsTest < ActionDispatch::IntegrationTest
  def setup
    @member = users(:two) # a plain member — edits go through review
    @admin = users(:one)
    @species = Species.create!(key: "perch", scientific_name: "Perca fluviatilis", water: :fresh)
    @upload = fixture_file_upload("avatar.png", "image/png")
  end

  test "a suggested species photo is attached when a moderator approves it" do
    sign_in_as(@member)
    assert_not @species.photo.attached?

    item = nil
    assert_difference -> { ModerationItem.where(kind: :edit).count }, 1 do
      patch species_path(@species, locale: :en), params: { species: { photo: @upload } }
    end

    # Not applied yet — still pending review.
    assert_not @species.reload.photo.attached?

    item = ModerationItem.where(kind: :edit, subject: @species).last
    assert item.revision.changeset.key?("photo"), "changeset should record the proposed photo"

    sign_in_as(@admin)
    item.approve!(@admin)

    assert @species.reload.photo.attached?, "approving should attach the suggested photo"
  end

  test "undoing an approved photo suggestion detaches it again" do
    sign_in_as(@member)
    patch species_path(@species, locale: :en), params: { species: { photo: @upload } }
    item = ModerationItem.where(kind: :edit, subject: @species).last

    item.approve!(@admin)
    assert @species.reload.photo.attached?

    item.undo!
    assert_not @species.reload.photo.attached?, "undo should roll the photo back off the record"
  end

  test "an admin photo edit attaches immediately without a queue item" do
    sign_in_as(@admin)
    assert_no_difference -> { ModerationItem.where(kind: :edit).count } do
      patch species_path(@species, locale: :en), params: { species: { photo: @upload } }
    end

    assert @species.reload.photo.attached?
  end
end
