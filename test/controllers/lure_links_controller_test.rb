require "test_helper"

class LureLinksControllerTest < ActionDispatch::IntegrationTest
  def setup
    @admin = users(:one)
    @member = users(:two)
    @type = LureType.create!(key: "jerkbait")
    @duo = Brand.create!(name: "DUO")
    @strike = Brand.create!(name: "Strike King")
    @realis = Lure.create!(brand: @duo, lure_type: @type, model: "Realis Jerkbait 120")
    @kvd = Lure.create!(brand: @strike, lure_type: @type, model: "KVD Jerkbait")
  end

  test "admin links two lures directly" do
    sign_in_as @admin

    assert_difference "LureLink.count", 1 do
      assert_no_difference "ModerationItem.count" do
        post lure_links_path(lure_id: @realis), params: { similar_lure: @kvd.slug }
      end
    end
    assert LureLink.involving(@realis).first.published?
    assert_includes @realis.similar_lures, @kvd
  end

  test "member link is created but queued for review" do
    sign_in_as @member

    assert_difference [ "LureLink.count", "ModerationItem.count" ], 1 do
      post lure_links_path(lure_id: @realis), params: { similar_lure: @kvd.slug }
    end

    link = LureLink.involving(@realis).first
    assert_not link.published?
    assert_empty @realis.similar_lures

    link.catalog_moderation_item.approve!(@admin)
    assert_includes @realis.similar_lures, @kvd
  end

  test "unknown lure slug is rejected gracefully" do
    sign_in_as @admin

    assert_no_difference "LureLink.count" do
      post lure_links_path(lure_id: @realis), params: { similar_lure: "nope" }
    end
    assert_redirected_to edit_lure_path(id: @realis)
  end

  test "member cannot remove a link" do
    link = LureLink.create!(lure: @realis, related_lure: @kvd)
    sign_in_as @member

    delete lure_link_path(lure_id: @realis, id: link)
    assert LureLink.exists?(link.id)
  end

  test "admin removes a link" do
    link = LureLink.create!(lure: @realis, related_lure: @kvd)
    sign_in_as @admin

    delete lure_link_path(lure_id: @realis, id: link)
    assert_not LureLink.exists?(link.id)
  end

  test "preview proposes lures whose colors match the uploaded photo" do
    matching = @kvd.variants.create!(name: "Red Craw")
    attach_drawn_photo(matching, "red")
    stamp_signature(matching)

    distant = @realis.variants.create!(name: "Blue Back")
    attach_drawn_photo(distant, "blue")
    stamp_signature(distant)

    sign_in_as @member
    new_lure = Lure.create!(brand: @duo, lure_type: @type, model: "Rozante 77")
    post lure_similar_preview_path(lure_id: new_lure),
         params: { photo: fixture_file_upload(draw("red"), "image/png") }

    assert_response :success
    slugs = response.parsed_body.map { |s| s["slug"] }
    assert_includes slugs, @kvd.slug
    assert_not_includes slugs, @realis.slug
  end

  test "preview excludes the lure being edited and requires a file" do
    variant = @kvd.variants.create!(name: "Red Craw")
    attach_drawn_photo(variant, "red")
    stamp_signature(variant)

    sign_in_as @member
    post lure_similar_preview_path(lure_id: @kvd),
         params: { photo: fixture_file_upload(draw("red"), "image/png") }
    assert_empty response.parsed_body

    post lure_similar_preview_path(lure_id: @kvd), params: { photo: "not-a-file" }
    assert_empty response.parsed_body
  end

  test "creating a color with ticked proposals links them" do
    sign_in_as @member

    assert_difference "LureLink.count", 1 do
      post variants_path(lure_id: @realis), params: {
        variant: { name: "Ghost Minnow" },
        similar_lure_slugs: [ @kvd.slug, "" ]
      }
    end
    link = LureLink.involving(@realis).first
    assert_equal @kvd, link.other_lure(@realis)
    assert_not link.published?
  end

  test "lure page shows published similar lures, hides links in review" do
    link = LureLink.create!(lure: @realis, related_lure: @kvd)
    ModerationItem.create!(subject: link, kind: :catalog, submitter: @member)

    get lure_path(id: @realis)
    assert_response :success
    assert_no_match @kvd.model, response.body

    link.catalog_moderation_item.approve!(@admin)
    get lure_path(id: @realis)
    assert_match @kvd.model, response.body
    assert_match I18n.t("lure.similar_title"), response.body
  end

  test "edit page renders the similar-lures management card" do
    LureLink.create!(lure: @realis, related_lure: @kvd)
    sign_in_as @admin

    get edit_lure_path(id: @realis)
    assert_response :success
    assert_match I18n.t("lure.similar_title"), response.body
    assert_match @kvd.model, response.body
  end

  test "new color form carries the similar-lures proposal hook" do
    sign_in_as @member

    get new_variant_path(lure_id: @realis)
    assert_response :success
    assert_match "similar-lures", response.body
    assert_match "similar-preview", response.body
  end

  private

  def draw(fill)
    path = File.join(Dir.mktmpdir, "#{fill}.png")
    MiniMagick.convert do |convert|
      convert.size("64x64")
      convert << "xc:white"
      convert.fill(fill)
      convert.draw("rectangle 12,20 52,44")
      convert << path
    end
    path
  end

  def attach_drawn_photo(variant, fill)
    path = draw(fill)
    variant.photo.attach(io: File.open(path), filename: File.basename(path), content_type: "image/png")
  end

  # Tests run jobs eagerly nowhere near AnalyzeJob, so write the signature the
  # analyzer would have produced straight into blob metadata.
  def stamp_signature(variant)
    blob = variant.photo.blob
    signature = ColorSignature.from_file(ActiveStorage::Blob.service.path_for(blob.key))
    blob.update!(metadata: blob.metadata.merge("color_signature" => signature.to_s))
  end
end
