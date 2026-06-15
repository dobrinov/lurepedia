require "test_helper"

class CommunityTest < ActiveSupport::TestCase
  def setup
    @type = LureType.create!(key: "jerkbait")
    @brand = Brand.create!(name: "Megabass")
    @lure = Lure.create!(brand: @brand, lure_type: @type, model: "Vision 110")
    @variant = @lure.variants.create!(name: "GG Ayu")
    @species = Species.create!(key: "largemouth_bass")
    @user = User.create!(name: "Marcus Lee", email_address: "m@example.com", password: "secret123")
    @other = User.create!(name: "Dana Powell", email_address: "d@example.com", password: "secret123")
    @catch = Catch.create!(user: @user, variant: @variant, species: @species, season: :spring, clarity: :clear)
  end

  test "catch counters bump variant, species and lure" do
    assert_equal 1, @variant.reload.catches_count
    assert_equal 1, @species.reload.catches_count
    assert_equal 1, @lure.reload.catches_count
  end

  test "catch reaches lure through variant" do
    assert_equal @lure, @catch.lure
  end

  test "condition pairs only include present values" do
    assert_equal({ season: "spring", clarity: "clear" }, @catch.condition_pairs)
  end

  test "upvote unique per user and maintains counter" do
    Upvote.create!(user: @other, catch: @catch)
    assert_equal 1, @catch.reload.upvotes_count
    dup = Upvote.new(user: @other, catch: @catch)
    assert_not dup.valid?
    assert @catch.upvoted_by?(@other)
  end

  test "comment maintains counter" do
    @catch.comments.create!(user: @other, body: "Nice fish")
    assert_equal 1, @catch.reload.comments_count
  end

  test "claim generates a verification token and verifies" do
    claim = Claim.create!(claimable: @brand, user: @user, email: "owner@megabass.com")
    assert_match(/\Alurepedia-verify=lp_brand_megabass_[0-9a-f]{6}\z/, claim.verification_token)
    assert claim.status_pending?
    claim.verify!
    assert claim.status_verified?
    assert @brand.reload.claimed?
  end

  test "report polymorphic with reason enum" do
    report = Report.create!(reportable: @catch, user: @other, reason: :fake)
    assert report.reason_fake?
    assert_equal 1, @catch.reports.count
  end

  test "moderation item actionability by role" do
    catch_item = ModerationItem.create!(subject: @catch, kind: :catch, submitter: @user, mod_actionable: true)
    claim_item = ModerationItem.create!(subject: @brand, kind: :claim, submitter: @user, mod_actionable: false)
    moderator = User.create!(name: "Mod", email_address: "mod@example.com", password: "secret123", role: :moderator)
    admin = User.create!(name: "Admin", email_address: "admin@example.com", password: "secret123", role: :admin)
    member = User.create!(name: "Member", email_address: "mem@example.com", password: "secret123", role: :member)

    assert catch_item.actionable_by?(moderator)
    assert_not claim_item.actionable_by?(moderator)
    assert claim_item.actionable_by?(admin)
    assert_not catch_item.actionable_by?(member)
  end

  test "moderation approve and undo" do
    admin = User.create!(name: "Admin", email_address: "a2@example.com", password: "secret123", role: :admin)
    item = ModerationItem.create!(subject: @catch, kind: :catch, submitter: @user)
    item.approve!(admin)
    assert item.status_approved?
    assert_equal admin, item.reviewer
    item.undo!
    assert item.status_pending?
  end

  test "revision timeline ordering" do
    r1 = Revision.create!(subject: @lure, user: @user, summary: "Created", created_at: 2.days.ago)
    r2 = Revision.create!(subject: @lure, user: @other, summary: "Edited", created_at: 1.day.ago)
    assert_equal [r1, r2], @lure.revisions.chronological.to_a
    assert_equal [r2, r1], @lure.revisions.newest_first.to_a
  end
end
