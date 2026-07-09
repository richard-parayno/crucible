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

ActiveRecord::Schema[8.1].define(version: 2026_07_09_145753) do
  create_table "environment_variables", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.boolean "enabled", default: true, null: false
    t.string "key", null: false
    t.integer "runtime_instance_id"
    t.string "scope", null: false
    t.boolean "sensitive", default: false, null: false
    t.datetime "updated_at", null: false
    t.text "value", null: false
    t.index ["runtime_instance_id", "key"], name: "index_environment_variables_on_runtime_instance_key", unique: true, where: "scope = 'runtime_instance' AND runtime_instance_id IS NOT NULL"
    t.index ["runtime_instance_id"], name: "index_environment_variables_on_runtime_instance_id"
    t.index ["scope", "key"], name: "index_environment_variables_on_system_key", unique: true, where: "scope = 'system' AND runtime_instance_id IS NULL"
    t.check_constraint "(scope = 'system' AND runtime_instance_id IS NULL) OR (scope = 'runtime_instance' AND runtime_instance_id IS NOT NULL)", name: "environment_variables_scope_runtime_instance_check"
    t.check_constraint "scope IN ('system', 'runtime_instance')", name: "environment_variables_scope_check"
  end

  create_table "runtime_artifacts", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "kind"
    t.json "metadata"
    t.string "path"
    t.integer "runtime_instance_id", null: false
    t.datetime "updated_at", null: false
    t.index ["runtime_instance_id"], name: "index_runtime_artifacts_on_runtime_instance_id"
  end

  create_table "runtime_definitions", force: :cascade do |t|
    t.boolean "active"
    t.json "config_schema"
    t.string "container_image"
    t.datetime "created_at", null: false
    t.text "default_command"
    t.json "default_env"
    t.text "description"
    t.string "kind"
    t.string "name"
    t.datetime "updated_at", null: false
  end

  create_table "runtime_events", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "level"
    t.text "message"
    t.json "metadata"
    t.datetime "occurred_at"
    t.integer "runtime_instance_id", null: false
    t.datetime "updated_at", null: false
    t.index ["runtime_instance_id"], name: "index_runtime_events_on_runtime_instance_id"
  end

  create_table "runtime_instances", force: :cascade do |t|
    t.json "config"
    t.string "container_name"
    t.string "container_runtime"
    t.datetime "created_at", null: false
    t.json "env"
    t.string "external_id"
    t.datetime "last_heartbeat_at"
    t.string "name"
    t.string "placement_kind"
    t.integer "runtime_definition_id", null: false
    t.datetime "started_at"
    t.string "status"
    t.text "status_message"
    t.datetime "stopped_at"
    t.datetime "updated_at", null: false
    t.integer "workspace_id", null: false
    t.index ["runtime_definition_id"], name: "index_runtime_instances_on_runtime_definition_id"
    t.index ["workspace_id"], name: "index_runtime_instances_on_workspace_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "name", null: false
    t.string "password_digest", null: false
    t.datetime "updated_at", null: false
    t.boolean "verified", default: false, null: false
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  create_table "workspaces", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name"
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_workspaces_on_user_id"
  end

  add_foreign_key "environment_variables", "runtime_instances"
  add_foreign_key "runtime_artifacts", "runtime_instances"
  add_foreign_key "runtime_events", "runtime_instances"
  add_foreign_key "runtime_instances", "runtime_definitions"
  add_foreign_key "runtime_instances", "workspaces"
  add_foreign_key "sessions", "users"
  add_foreign_key "workspaces", "users"
end
