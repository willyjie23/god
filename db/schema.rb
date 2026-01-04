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

ActiveRecord::Schema[8.1].define(version: 2026_01_04_132840) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_admin_comments", force: :cascade do |t|
    t.bigint "author_id"
    t.string "author_type"
    t.text "body"
    t.datetime "created_at", null: false
    t.string "namespace"
    t.bigint "resource_id"
    t.string "resource_type"
    t.datetime "updated_at", null: false
    t.index ["author_type", "author_id"], name: "index_active_admin_comments_on_author"
    t.index ["namespace"], name: "index_active_admin_comments_on_namespace"
    t.index ["resource_type", "resource_id"], name: "index_active_admin_comments_on_resource"
  end

  create_table "admin_users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_admin_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_admin_users_on_reset_password_token", unique: true
  end

  create_table "donations", force: :cascade do |t|
    t.decimal "amount", precision: 10, scale: 2, null: false
    t.string "atm_bank_code"
    t.string "atm_v_account"
    t.datetime "created_at", null: false
    t.string "created_by", default: "frontend", null: false
    t.string "cvs_barcode_1"
    t.string "cvs_barcode_2"
    t.string "cvs_barcode_3"
    t.string "cvs_payment_no"
    t.string "donation_type", null: false
    t.string "donor_name", null: false
    t.datetime "ecpay_payment_date"
    t.string "ecpay_payment_type"
    t.string "ecpay_rtn_code"
    t.string "ecpay_rtn_msg"
    t.boolean "ecpay_simulate_paid", default: false
    t.integer "ecpay_trade_amt"
    t.string "ecpay_trade_no"
    t.string "email"
    t.string "merchant_trade_no"
    t.boolean "needs_receipt", default: false, null: false
    t.text "notes"
    t.datetime "paid_at"
    t.datetime "payment_expire_date"
    t.string "payment_method"
    t.string "phone"
    t.text "prayer"
    t.string "status", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_donations_on_created_at"
    t.index ["donation_type"], name: "index_donations_on_donation_type"
    t.index ["ecpay_payment_type"], name: "index_donations_on_ecpay_payment_type"
    t.index ["ecpay_trade_no"], name: "index_donations_on_ecpay_trade_no"
    t.index ["merchant_trade_no"], name: "index_donations_on_merchant_trade_no"
    t.index ["status"], name: "index_donations_on_status"
  end
end
