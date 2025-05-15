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

ActiveRecord::Schema[7.1].define(version: 2025_04_30_062147) do
  create_table "action_text_rich_texts", force: :cascade do |t|
    t.string "name", null: false
    t.text "body"
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["record_type", "record_id", "name"], name: "index_action_text_rich_texts_uniqueness", unique: true
  end

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "credentials", force: :cascade do |t|
    t.string "name"
    t.string "secure_username"
    t.string "secure_password"
    t.string "secure_content"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "folders", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "folders_items", force: :cascade do |t|
    t.string "resource_type"
    t.integer "resource_id"
    t.integer "folder_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["folder_id"], name: "index_folders_items_on_folder_id"
    t.index ["resource_type", "resource_id"], name: "index_folders_items_on_resource"
  end

  create_table "notifications", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "typology", default: 0
    t.json "data"
    t.boolean "managed", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_notifications_on_user_id"
  end

  create_table "posts", force: :cascade do |t|
    t.integer "user_id"
    t.string "content"
    t.string "tags"
    t.string "source_url"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_posts_on_user_id"
  end

  create_table "presentations", force: :cascade do |t|
    t.string "name"
    t.string "description"
    t.integer "project_id"
    t.integer "width_px"
    t.integer "height_px"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "share_code"
    t.index ["project_id"], name: "index_presentations_on_project_id"
  end

  create_table "presentations_actions", force: :cascade do |t|
    t.integer "presentation_id", null: false
    t.integer "presentations_page_id", null: false
    t.float "position_x", default: 0.0
    t.float "position_y", default: 0.0
    t.integer "page_destination"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["presentation_id"], name: "index_presentations_actions_on_presentation_id"
    t.index ["presentations_page_id"], name: "index_presentations_actions_on_presentations_page_id"
  end

  create_table "presentations_notes", force: :cascade do |t|
    t.integer "presentation_id", null: false
    t.integer "presentations_page_id", null: false
    t.float "position_x", default: 0.0
    t.float "position_y", default: 0.0
    t.text "content"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["presentation_id"], name: "index_presentations_notes_on_presentation_id"
    t.index ["presentations_page_id"], name: "index_presentations_notes_on_presentations_page_id"
  end

  create_table "presentations_pages", force: :cascade do |t|
    t.integer "presentation_id", null: false
    t.string "title"
    t.string "image_name"
    t.integer "order", default: 1
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["presentation_id"], name: "index_presentations_pages_on_presentation_id"
  end

  create_table "procedures", force: :cascade do |t|
    t.string "name"
    t.string "description"
    t.integer "resources_type", default: 0
    t.boolean "archived", default: false
    t.boolean "model", default: false
    t.integer "items_count", default: 0
    t.integer "statuses_count", default: 0
    t.integer "project_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "show_archived_projects", default: false
    t.boolean "project_primary", default: false
    t.index ["project_id"], name: "index_procedures_on_project_id"
  end

  create_table "procedures_items", force: :cascade do |t|
    t.integer "procedure_id", null: false
    t.integer "procedures_status_id", null: false
    t.string "title"
    t.integer "order", default: 1
    t.string "resource_type"
    t.integer "resource_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.json "model_data"
    t.index ["procedure_id"], name: "index_procedures_items_on_procedure_id"
    t.index ["procedures_status_id"], name: "index_procedures_items_on_procedures_status_id"
    t.index ["resource_type", "resource_id"], name: "index_procedures_items_on_resource"
  end

  create_table "procedures_status_automations", force: :cascade do |t|
    t.integer "procedures_status_id", null: false
    t.integer "typology", default: 0
    t.json "data"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["procedures_status_id"], name: "index_procedures_status_automations_on_procedures_status_id"
  end

  create_table "procedures_statuses", force: :cascade do |t|
    t.integer "procedure_id", null: false
    t.string "title"
    t.integer "order", default: 1
    t.integer "items_count", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "description"
    t.index ["procedure_id"], name: "index_procedures_statuses_on_procedure_id"
  end

  create_table "projects", force: :cascade do |t|
    t.string "code", null: false
    t.string "name"
    t.string "description"
    t.boolean "archived", default: false
    t.integer "archived_reason", default: 0
    t.integer "year", limit: 4
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "slack_channel_id"
    t.boolean "budget_management", default: false
    t.integer "budget_money", default: 0
    t.integer "budget_time", default: 0
    t.integer "alghoritmic_order", default: 1
    t.index ["code"], name: "index_projects_on_code", unique: true
  end

  create_table "projects_attachments", force: :cascade do |t|
    t.integer "project_id", null: false
    t.integer "typology", default: 0
    t.string "title"
    t.string "description"
    t.integer "version"
    t.date "date"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["project_id"], name: "index_projects_attachments_on_project_id"
  end

  create_table "projects_events", force: :cascade do |t|
    t.integer "project_id", null: false
    t.string "message"
    t.json "data"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["project_id"], name: "index_projects_events_on_project_id"
  end

  create_table "projects_logs", force: :cascade do |t|
    t.integer "project_id", null: false
    t.integer "user_id", null: false
    t.string "title"
    t.date "date"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "share_code"
    t.index ["project_id"], name: "index_projects_logs_on_project_id"
    t.index ["user_id"], name: "index_projects_logs_on_user_id"
  end

  create_table "projects_members", force: :cascade do |t|
    t.integer "project_id", null: false
    t.integer "user_id", null: false
    t.string "role"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["project_id"], name: "index_projects_members_on_project_id"
    t.index ["user_id"], name: "index_projects_members_on_user_id"
  end

  create_table "settings", force: :cascade do |t|
    t.string "key"
    t.json "data"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "tasks", force: :cascade do |t|
    t.integer "user_id"
    t.string "title"
    t.string "output"
    t.date "deadline"
    t.integer "time_estimate"
    t.integer "time_spent", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "completed", default: false
    t.datetime "completed_at"
    t.integer "project_id"
    t.boolean "repeat", default: false
    t.date "repeat_from"
    t.date "repeat_to"
    t.json "repeat_weekdays", default: []
    t.integer "repeat_original_task_id"
    t.integer "alghoritmic_order", default: 1
    t.integer "repeat_type", default: 0, null: false
    t.integer "repeat_monthday", default: 0, null: false
    t.boolean "accepted", default: true
    t.index ["project_id"], name: "index_tasks_on_project_id"
    t.index ["user_id"], name: "index_tasks_on_user_id"
  end

  create_table "tasks_checks", force: :cascade do |t|
    t.integer "task_id", null: false
    t.string "text"
    t.boolean "checked", default: false
    t.integer "order", default: 1
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["task_id"], name: "index_tasks_checks_on_task_id"
  end

  create_table "tasks_followers", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "task_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["task_id"], name: "index_tasks_followers_on_task_id"
    t.index ["user_id"], name: "index_tasks_followers_on_user_id"
  end

  create_table "tasks_tracks", force: :cascade do |t|
    t.integer "task_id", null: false
    t.integer "user_id"
    t.datetime "start_at"
    t.datetime "end_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "ping_at"
    t.integer "time_spent", default: 0
    t.index ["task_id"], name: "index_tasks_tracks_on_task_id"
    t.index ["user_id"], name: "index_tasks_tracks_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "name"
    t.string "surname"
    t.string "email", null: false
    t.string "password_digest"
    t.boolean "admin", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  create_table "users_logs", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "typology", default: 0, null: false
    t.string "value"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_users_logs_on_user_id"
  end

  create_table "users_policies", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "policy"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_users_policies_on_user_id"
  end

  create_table "users_prefers", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "resource_type"
    t.integer "resource_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["resource_type", "resource_id"], name: "index_users_prefers_on_resource"
    t.index ["user_id"], name: "index_users_prefers_on_user_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "notifications", "users"
  add_foreign_key "posts", "users"
  add_foreign_key "presentations", "projects"
  add_foreign_key "presentations_actions", "presentations"
  add_foreign_key "presentations_actions", "presentations_pages"
  add_foreign_key "presentations_notes", "presentations"
  add_foreign_key "presentations_notes", "presentations_pages"
  add_foreign_key "presentations_pages", "presentations"
  add_foreign_key "procedures", "projects"
  add_foreign_key "procedures_items", "procedures"
  add_foreign_key "procedures_items", "procedures_statuses"
  add_foreign_key "procedures_status_automations", "procedures_statuses"
  add_foreign_key "procedures_statuses", "procedures"
  add_foreign_key "projects_attachments", "projects"
  add_foreign_key "projects_events", "projects"
  add_foreign_key "projects_logs", "projects"
  add_foreign_key "projects_logs", "users"
  add_foreign_key "projects_members", "projects"
  add_foreign_key "projects_members", "users"
  add_foreign_key "tasks", "projects"
  add_foreign_key "tasks", "users"
  add_foreign_key "tasks_checks", "tasks"
  add_foreign_key "tasks_followers", "tasks"
  add_foreign_key "tasks_followers", "users"
  add_foreign_key "tasks_tracks", "tasks"
  add_foreign_key "tasks_tracks", "users"
  add_foreign_key "users_logs", "users"
  add_foreign_key "users_policies", "users"
  add_foreign_key "users_prefers", "users"
end
