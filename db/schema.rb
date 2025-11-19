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

ActiveRecord::Schema[8.0].define(version: 2025_11_19_125941) do
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

  create_table "google_accounts", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "login_customer_id", null: false
    t.string "refresh_token_ciphertext", null: false
    t.text "scopes", default: [], array: true
    t.datetime "last_synced_at"
    t.string "status", default: "active", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "login_customer_id"], name: "index_google_accounts_on_user_id_and_login_customer_id", unique: true
    t.index ["user_id"], name: "index_google_accounts_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "accessible_customers", "google_accounts"
  add_foreign_key "active_customer_selections", "google_accounts"
  add_foreign_key "active_customer_selections", "users"
  add_foreign_key "google_accounts", "users"
end
