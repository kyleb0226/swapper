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

ActiveRecord::Schema[8.1].define(version: 2026_10_10_000001) do
  create_table "audit_events", force: :cascade do |t|
    t.integer "company_id"
    t.integer "user_id"
    t.string "action", null: false
    t.string "subject_type"
    t.bigint "subject_id"
    t.string "summary"
    t.datetime "created_at", null: false
    t.index ["company_id", "created_at"], name: "index_audit_events_on_company_id_and_created_at"
    t.index ["company_id"], name: "index_audit_events_on_company_id"
    t.index ["user_id"], name: "index_audit_events_on_user_id"
  end

  create_table "companies", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "employees", force: :cascade do |t|
    t.integer "company_id", null: false
    t.integer "user_id"
    t.string "name", null: false
    t.string "email"
    t.string "job_title", null: false
    t.string "job_code"
    t.integer "seniority", default: 0, null: false
    t.integer "current_location_id", null: false
    t.integer "desired_location_id"
    t.text "request_note"
    t.datetime "swap_requested_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id", "email"], name: "index_employees_on_company_id_and_email"
    t.index ["company_id"], name: "index_employees_on_company_id"
    t.index ["current_location_id"], name: "index_employees_on_current_location_id"
    t.index ["desired_location_id"], name: "index_employees_on_desired_location_id"
    t.index ["user_id"], name: "index_employees_on_user_id", unique: true
  end

  create_table "locations", force: :cascade do |t|
    t.integer "company_id", null: false
    t.string "name", null: false
    t.string "region"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id", "name"], name: "index_locations_on_company_id_and_name", unique: true
    t.index ["company_id"], name: "index_locations_on_company_id"
  end

  create_table "matches", force: :cascade do |t|
    t.integer "company_id", null: false
    t.integer "employee_id", null: false
    t.integer "matched_employee_id", null: false
    t.string "match_type", null: false
    t.string "status", default: "pending", null: false
    t.integer "decided_by_id"
    t.datetime "decided_at"
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id", "status"], name: "index_matches_on_company_id_and_status"
    t.index ["company_id"], name: "index_matches_on_company_id"
    t.index ["decided_by_id"], name: "index_matches_on_decided_by_id"
    t.index ["employee_id", "matched_employee_id"], name: "index_matches_on_employee_id_and_matched_employee_id", unique: true
    t.index ["employee_id"], name: "index_matches_on_employee_id"
    t.index ["matched_employee_id"], name: "index_matches_on_matched_employee_id"
  end

  create_table "outreach_email_templates", force: :cascade do |t|
    t.string "name", null: false
    t.string "subject", null: false
    t.text "body", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "outreach_emails", force: :cascade do |t|
    t.integer "prospect_id", null: false
    t.integer "email_template_id"
    t.string "to", null: false
    t.string "subject", null: false
    t.text "body", null: false
    t.string "status", default: "queued", null: false
    t.text "error"
    t.datetime "sent_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "follow_up", default: false, null: false
    t.index ["created_at"], name: "index_outreach_emails_on_created_at"
    t.index ["email_template_id"], name: "index_outreach_emails_on_email_template_id"
    t.index ["prospect_id"], name: "index_outreach_emails_on_prospect_id"
  end

  create_table "outreach_prospects", force: :cascade do |t|
    t.string "organization", null: false
    t.string "contact_name"
    t.string "contact_title"
    t.string "email"
    t.string "phone"
    t.string "website"
    t.string "sector"
    t.string "city"
    t.string "state"
    t.string "source"
    t.string "status", default: "new", null: false
    t.text "notes"
    t.datetime "last_contacted_at"
    t.datetime "unsubscribed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_outreach_prospects_on_email", unique: true, where: "email IS NOT NULL"
    t.index ["status"], name: "index_outreach_prospects_on_status"
  end

  create_table "outreach_suppressions", force: :cascade do |t|
    t.string "email"
    t.string "domain"
    t.string "reason", null: false
    t.string "note"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["domain"], name: "index_outreach_suppressions_on_domain", unique: true, where: "domain IS NOT NULL"
    t.index ["email"], name: "index_outreach_suppressions_on_email", unique: true, where: "email IS NOT NULL"
  end

  create_table "users", force: :cascade do |t|
    t.integer "company_id"
    t.string "name"
    t.string "email", null: false
    t.string "password_digest", null: false
    t.string "role", default: "employee", null: false
    t.boolean "platform_admin", default: false, null: false
    t.datetime "invited_at"
    t.datetime "activated_at"
    t.datetime "last_sign_in_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id"], name: "index_users_on_company_id"
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  add_foreign_key "audit_events", "companies"
  add_foreign_key "audit_events", "users"
  add_foreign_key "employees", "companies"
  add_foreign_key "employees", "locations", column: "current_location_id"
  add_foreign_key "employees", "locations", column: "desired_location_id"
  add_foreign_key "employees", "users"
  add_foreign_key "locations", "companies"
  add_foreign_key "matches", "companies"
  add_foreign_key "matches", "employees"
  add_foreign_key "matches", "employees", column: "matched_employee_id"
  add_foreign_key "matches", "users", column: "decided_by_id"
  add_foreign_key "outreach_emails", "outreach_email_templates", column: "email_template_id"
  add_foreign_key "outreach_emails", "outreach_prospects", column: "prospect_id"
  add_foreign_key "users", "companies"
end
