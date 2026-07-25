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

ActiveRecord::Schema[8.1].define(version: 2026_07_25_185408) do
  create_table "test_case_results", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "description"
    t.text "error_backtrace"
    t.text "error_message"
    t.string "file_path"
    t.string "full_description", null: false
    t.integer "line_number"
    t.float "run_time"
    t.string "status", null: false
    t.integer "test_run_id", null: false
    t.datetime "updated_at", null: false
    t.index ["test_run_id", "status"], name: "index_test_case_results_on_test_run_id_and_status"
    t.index ["test_run_id"], name: "index_test_case_results_on_test_run_id"
  end

  create_table "test_runs", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "error_message"
    t.integer "failed_count", default: 0, null: false
    t.datetime "finished_at"
    t.integer "passed_count", default: 0, null: false
    t.integer "pending_count", default: 0, null: false
    t.datetime "started_at"
    t.string "status", default: "pending", null: false
    t.string "target_url"
    t.integer "total_count", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index "(1)", name: "index_test_runs_on_active_status", unique: true, where: "status IN ('pending','running')"
    t.index ["status"], name: "index_test_runs_on_status"
  end

  add_foreign_key "test_case_results", "test_runs"
end
