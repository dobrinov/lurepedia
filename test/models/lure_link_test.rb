require "test_helper"

class LureLinkTest < ActiveSupport::TestCase
  def setup
    @type = LureType.create!(key: "jerkbait")
    @duo = Brand.create!(name: "DUO")
    @strike = Brand.create!(name: "Strike King")
    @realis = Lure.create!(brand: @duo, lure_type: @type, model: "Realis Jerkbait 120")
    @kvd = Lure.create!(brand: @strike, lure_type: @type, model: "KVD Jerkbait")
  end

  test "stores the symmetric pair lower-id-first" do
    link = LureLink.create!(lure: @kvd, related_lure: @realis)

    assert_equal [ @realis.id, @kvd.id ].sort, [ link.lure_id, link.related_lure_id ]
  end

  test "rejects the reverse duplicate of an existing pair" do
    LureLink.create!(lure: @realis, related_lure: @kvd)

    dup = LureLink.new(lure: @kvd, related_lure: @realis)
    assert_not dup.valid?
  end

  test "rejects a self link" do
    assert_not LureLink.new(lure: @realis, related_lure: @realis).valid?
  end

  test "other_lure returns the far end regardless of direction" do
    link = LureLink.create!(lure: @realis, related_lure: @kvd)

    assert_equal @kvd, link.other_lure(@realis)
    assert_equal @realis, link.other_lure(@kvd)
  end

  test "similar_lures resolves both directions but only published links by default" do
    link = LureLink.create!(lure: @realis, related_lure: @kvd)
    item = ModerationItem.create!(subject: link, kind: :catalog, submitter: users(:two))

    assert_empty @realis.similar_lures
    assert_includes @realis.similar_lures(links: LureLink.all), @kvd

    item.approve!(users(:one))
    assert_includes @realis.similar_lures, @kvd
    assert_includes @kvd.similar_lures, @realis
  end

  test "destroying a lure removes links from both sides" do
    LureLink.create!(lure: @realis, related_lure: @kvd)
    @kvd.destroy

    assert_empty LureLink.involving(@realis)
  end
end
