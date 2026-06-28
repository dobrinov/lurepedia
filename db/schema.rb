# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_06_28_203513) do
  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "bans", force: :cascade do |t|
    t.json "capabilities", default: [], null: false
    t.datetime "created_at", null: false
    t.datetime "expires_at"
    t.integer "issued_by_id", null: false
    t.text "reason", null: false
    t.datetime "revoked_at"
    t.integer "revoked_by_id"
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["issued_by_id"], name: "index_bans_on_issued_by_id"
    t.index ["revoked_by_id"], name: "index_bans_on_revoked_by_id"
    t.index ["user_id", "revoked_at", "expires_at"], name: "index_bans_on_user_id_and_revoked_at_and_expires_at"
    t.index ["user_id"], name: "index_bans_on_user_id"
  end

  create_table "brands", force: :cascade do |t|
    t.text "blurb"
    t.string "country"
    t.datetime "created_at", null: false
    t.integer "founded_year"
    t.integer "lures_count", default: 0, null: false
    t.string "name", null: false
    t.string "slug", null: false
    t.datetime "updated_at", null: false
    t.string "website"
    t.index ["slug"], name: "index_brands_on_slug", unique: true
  end

  create_table "builds", force: :cascade do |t|
    t.integer "action", default: 0, null: false
    t.integer "catches_count", default: 0, null: false
    t.datetime "created_at", null: false
    t.integer "depth_max_cm"
    t.integer "depth_min_cm"
    t.integer "length_mm"
    t.integer "lure_id", null: false
    t.string "name", null: false
    t.integer "position", default: 0, null: false
    t.datetime "updated_at", null: false
    t.integer "water", default: 0, null: false
    t.decimal "weight_g", precision: 8, scale: 2
    t.index ["lure_id"], name: "index_builds_on_lure_id"
  end

  create_table "buy_links", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "lure_id", null: false
    t.integer "shop_id", null: false
    t.datetime "updated_at", null: false
    t.string "url"
    t.index ["lure_id"], name: "index_buy_links_on_lure_id"
    t.index ["shop_id"], name: "index_buy_links_on_shop_id"
  end

  create_table "catches", force: :cascade do |t|
    t.integer "build_id"
    t.integer "clarity"
    t.integer "comments_count", default: 0, null: false
    t.datetime "created_at", null: false
    t.decimal "length_cm", precision: 8, scale: 2
    t.string "location"
    t.text "note"
    t.integer "platform"
    t.integer "retrieve"
    t.integer "season"
    t.integer "species_id", null: false
    t.integer "time_of_day"
    t.datetime "updated_at", null: false
    t.integer "upvotes_count", default: 0, null: false
    t.integer "user_id", null: false
    t.integer "variant_id", null: false
    t.integer "water_body"
    t.decimal "weight_g", precision: 8, scale: 2
    t.integer "wind"
    t.index ["build_id"], name: "index_catches_on_build_id"
    t.index ["species_id"], name: "index_catches_on_species_id"
    t.index ["user_id"], name: "index_catches_on_user_id"
    t.index ["variant_id"], name: "index_catches_on_variant_id"
  end

  create_table "claims", force: :cascade do |t|
    t.integer "claimable_id", null: false
    t.string "claimable_type", null: false
    t.datetime "created_at", null: false
    t.datetime "dns_verified_at"
    t.string "email"
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.string "verification_token", null: false
    t.index ["claimable_type", "claimable_id"], name: "index_claims_on_claimable"
    t.index ["user_id"], name: "index_claims_on_user_id"
  end

  create_table "comments", force: :cascade do |t|
    t.text "body", null: false
    t.integer "catch_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["catch_id"], name: "index_comments_on_catch_id"
    t.index ["user_id"], name: "index_comments_on_user_id"
  end

  create_table "favorites", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "favoritable_id", null: false
    t.string "favoritable_type", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["favoritable_type", "favoritable_id"], name: "index_favorites_on_favoritable"
    t.index ["user_id", "favoritable_type", "favoritable_id"], name: "index_favorites_on_user_and_favoritable", unique: true
    t.index ["user_id"], name: "index_favorites_on_user_id"
  end

  create_table "lure_types", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "key", null: false
    t.datetime "updated_at", null: false
    t.integer "water_default", default: 0, null: false
    t.index ["key"], name: "index_lure_types_on_key", unique: true
  end

  create_table "lures", force: :cascade do |t|
    t.string "action_video_url"
    t.text "blurb"
    t.integer "brand_id", null: false
    t.integer "catches_count", default: 0, null: false
    t.datetime "created_at", null: false
    t.integer "default_variant_id"
    t.integer "lure_type_id", null: false
    t.string "model", null: false
    t.string "slug", null: false
    t.datetime "updated_at", null: false
    t.index ["brand_id"], name: "index_lures_on_brand_id"
    t.index ["default_variant_id"], name: "index_lures_on_default_variant_id"
    t.index ["lure_type_id"], name: "index_lures_on_lure_type_id"
    t.index ["slug"], name: "index_lures_on_slug", unique: true
  end

  create_table "moderation_items", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "kind", default: 0, null: false
    t.boolean "mod_actionable", default: true, null: false
    t.datetime "reviewed_at"
    t.integer "reviewer_id"
    t.integer "revision_id"
    t.integer "status", default: 0, null: false
    t.integer "subject_id", null: false
    t.string "subject_type", null: false
    t.integer "submitter_id"
    t.datetime "updated_at", null: false
    t.index ["reviewer_id"], name: "index_moderation_items_on_reviewer_id"
    t.index ["revision_id"], name: "index_moderation_items_on_revision_id"
    t.index ["subject_type", "subject_id"], name: "index_moderation_items_on_subject"
    t.index ["submitter_id"], name: "index_moderation_items_on_submitter_id"
  end

  create_table "reports", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "note"
    t.integer "reason", default: 0, null: false
    t.integer "reportable_id", null: false
    t.string "reportable_type", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["reportable_type", "reportable_id"], name: "index_reports_on_reportable"
    t.index ["user_id"], name: "index_reports_on_user_id"
  end

  create_table "revisions", force: :cascade do |t|
    t.boolean "applied", default: true, null: false
    t.json "changeset"
    t.datetime "created_at", null: false
    t.integer "subject_id", null: false
    t.string "subject_type", null: false
    t.string "summary", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id"
    t.index ["subject_type", "subject_id"], name: "index_revisions_on_subject"
    t.index ["user_id"], name: "index_revisions_on_user_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "shops", force: :cascade do |t|
    t.text "blurb"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.boolean "promoted", default: false, null: false
    t.string "ships_to"
    t.boolean "ships_worldwide", default: false, null: false
    t.string "slug", null: false
    t.datetime "updated_at", null: false
    t.string "url"
    t.index ["slug"], name: "index_shops_on_slug", unique: true
  end

  create_table "species", force: :cascade do |t|
    t.integer "catches_count", default: 0, null: false
    t.datetime "created_at", null: false
    t.string "key", null: false
    t.string "scientific_name"
    t.string "slug", null: false
    t.datetime "updated_at", null: false
    t.integer "water", default: 0, null: false
    t.string "wikipedia_url"
    t.index ["key"], name: "index_species_on_key", unique: true
    t.index ["slug"], name: "index_species_on_slug", unique: true
  end

  create_table "upvotes", force: :cascade do |t|
    t.integer "catch_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["catch_id"], name: "index_upvotes_on_catch_id"
    t.index ["user_id", "catch_id"], name: "index_upvotes_on_user_id_and_catch_id", unique: true
    t.index ["user_id"], name: "index_upvotes_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.text "bio"
    t.string "country", default: "US", null: false
    t.datetime "created_at", null: false
    t.integer "depth_units", default: 0, null: false
    t.string "email_address", null: false
    t.integer "length_units", default: 0, null: false
    t.string "locale", default: "en", null: false
    t.string "name", default: "", null: false
    t.string "password_digest", null: false
    t.integer "role", default: 0, null: false
    t.string "slug", null: false
    t.datetime "updated_at", null: false
    t.string "username"
    t.integer "weight_units", default: 0, null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
    t.index ["slug"], name: "index_users_on_slug", unique: true
    t.index ["username"], name: "index_users_on_username", unique: true
  end

  create_table "variants", force: :cascade do |t|
    t.string "best_for"
    t.integer "catches_count", default: 0, null: false
    t.datetime "created_at", null: false
    t.integer "lure_id", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.boolean "uv_glow", default: false, null: false
    t.index ["lure_id"], name: "index_variants_on_lure_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "bans", "users"
  add_foreign_key "bans", "users", column: "issued_by_id"
  add_foreign_key "bans", "users", column: "revoked_by_id"
  add_foreign_key "buy_links", "lures"
  add_foreign_key "buy_links", "shops"
  add_foreign_key "catches", "species"
  add_foreign_key "catches", "users"
  add_foreign_key "catches", "variants"
  add_foreign_key "claims", "users"
  add_foreign_key "comments", "catches"
  add_foreign_key "comments", "users"
  add_foreign_key "favorites", "users"
  add_foreign_key "lures", "brands"
  add_foreign_key "lures", "lure_types"
  add_foreign_key "moderation_items", "revisions"
  add_foreign_key "moderation_items", "users", column: "reviewer_id"
  add_foreign_key "moderation_items", "users", column: "submitter_id"
  add_foreign_key "reports", "users"
  add_foreign_key "revisions", "users"
  add_foreign_key "sessions", "users"
  add_foreign_key "upvotes", "catches"
  add_foreign_key "upvotes", "users"
  add_foreign_key "variants", "lures"
end
