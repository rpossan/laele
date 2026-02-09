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

ActiveRecord::Schema[8.0].define(version: 2026_02_06_140000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "accessible_customers", force: :cascade do |t|
    t.bigint "google_account_id", null: false
    t.string "customer_id", null: false
    t.string "display_name"
    t.string "currency_code"
    t.string "role"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "custom_name"
    t.boolean "active", default: false, null: false
    t.index ["active"], name: "index_accessible_customers_on_active"
    t.index ["google_account_id", "customer_id"], name: "index_accessible_customers_on_account_and_customer", unique: true
    t.index ["google_account_id"], name: "index_accessible_customers_on_google_account_id"
  end

  create_table "active_customer_selections", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "google_account_id", null: false
    t.string "customer_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["google_account_id"], name: "index_active_customer_selections_on_google_account_id"
    t.index ["user_id"], name: "index_active_customer_selections_on_user_id_unique", unique: true
  end

  create_table "activity_logs", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "action", null: false
    t.string "resource_type"
    t.string "resource_id"
    t.jsonb "metadata", default: {}
    t.text "description"
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["action", "created_at"], name: "index_activity_logs_on_action_and_created_at"
    t.index ["resource_type", "resource_id"], name: "index_activity_logs_on_resource_type_and_resource_id"
    t.index ["user_id", "created_at"], name: "index_activity_logs_on_user_id_and_created_at"
    t.index ["user_id"], name: "index_activity_logs_on_user_id"
  end

  create_table "geo_targets", force: :cascade do |t|
    t.string "criteria_id"
    t.string "name"
    t.string "canonical_name"
    t.string "parent_id"
    t.string "country_code"
    t.string "target_type"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["canonical_name"], name: "index_geo_targets_on_canonical_name"
    t.index ["country_code"], name: "index_geo_targets_on_country_code"
    t.index ["criteria_id"], name: "index_geo_targets_on_criteria_id", unique: true
    t.index ["name"], name: "index_geo_targets_on_name"
    t.index ["target_type"], name: "index_geo_targets_on_target_type"
  end

  create_table "google_accounts", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "login_customer_id"
    t.string "refresh_token_ciphertext"
    t.text "scopes", default: [], array: true
    t.datetime "last_synced_at"
    t.string "status", default: "active", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "refresh_token"
    t.index ["user_id", "login_customer_id"], name: "index_google_accounts_on_user_id_and_login_customer_id", unique: true
    t.index ["user_id"], name: "index_google_accounts_on_user_id"
  end

  create_table "lead_feedback_submissions", force: :cascade do |t|
    t.bigint "google_account_id", null: false
    t.string "lead_id", null: false
    t.string "survey_answer", null: false
    t.string "reason"
    t.text "other_reason_comment"
    t.string "credit_issuance_decision", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["google_account_id", "lead_id"], name: "index_lead_feedback_submissions_on_account_and_lead", unique: true
    t.index ["google_account_id"], name: "index_lead_feedback_submissions_on_google_account_id"
    t.index ["lead_id"], name: "index_lead_feedback_submissions_on_lead_id"
  end

  create_table "plans", force: :cascade do |t|
    t.string "slug", null: false
    t.string "name", null: false
    t.text "description"
    t.string "pricing_type", null: false
    t.integer "price_cents_brl", null: false
    t.integer "price_cents_usd", null: false
    t.integer "max_accounts"
    t.integer "price_per_account_cents_brl"
    t.integer "price_per_account_cents_usd"
    t.boolean "recommended", default: false, null: false
    t.boolean "active", default: true, null: false
    t.integer "position", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "stripe_price_id_brl"
    t.string "stripe_price_id_usd"
    t.index ["active"], name: "index_plans_on_active"
    t.index ["position"], name: "index_plans_on_position"
    t.index ["slug"], name: "index_plans_on_slug", unique: true
    t.index ["stripe_price_id_brl"], name: "index_plans_on_stripe_price_id_brl"
    t.index ["stripe_price_id_usd"], name: "index_plans_on_stripe_price_id_usd"
  end

  create_table "user_subscriptions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "plan_id", null: false
    t.string "status", default: "pending", null: false
    t.integer "selected_accounts_count"
    t.integer "calculated_price_cents_brl"
    t.integer "calculated_price_cents_usd"
    t.datetime "started_at"
    t.datetime "expires_at"
    t.datetime "cancelled_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "stripe_customer_id"
    t.string "stripe_subscription_id"
    t.index ["expires_at"], name: "index_user_subscriptions_on_expires_at"
    t.index ["plan_id"], name: "index_user_subscriptions_on_plan_id"
    t.index ["status"], name: "index_user_subscriptions_on_status"
    t.index ["stripe_customer_id"], name: "index_user_subscriptions_on_stripe_customer_id"
    t.index ["stripe_subscription_id"], name: "index_user_subscriptions_on_stripe_subscription_id"
    t.index ["user_id"], name: "index_user_subscriptions_on_user_id", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "allowed", default: false, null: false
    t.index ["allowed"], name: "index_users_on_allowed"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "accessible_customers", "google_accounts"
  add_foreign_key "active_customer_selections", "google_accounts"
  add_foreign_key "active_customer_selections", "users"
  add_foreign_key "activity_logs", "users"
  add_foreign_key "google_accounts", "users"
  add_foreign_key "lead_feedback_submissions", "google_accounts"
  add_foreign_key "user_subscriptions", "plans"
  add_foreign_key "user_subscriptions", "users"
end
