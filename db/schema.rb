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

ActiveRecord::Schema[7.1].define(version: 2025_08_24_131320) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"
  enable_extension "vector"

  create_table "analyses", force: :cascade do |t|
    t.bigint "conversation_id", null: false
    t.string "analysis_type"
    t.jsonb "analysis_data"
    t.string "priority_level"
    t.string "sentiment"
    t.boolean "escalated"
    t.datetime "escalated_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.jsonb "hidden_needs"
    t.text "escalation_reason"
    t.datetime "analyzed_at"
    t.float "confidence_score"
    t.string "customer_sentiment"
    t.text "escalation_reasons"
    t.index ["analyzed_at"], name: "index_analyses_on_analyzed_at"
    t.index ["conversation_id"], name: "index_analyses_on_conversation_id"
    t.index ["customer_sentiment"], name: "index_analyses_on_customer_sentiment"
    t.index ["hidden_needs"], name: "index_analyses_on_hidden_needs", using: :gin
  end

  create_table "conversations", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "session_id"
    t.datetime "ended_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.jsonb "metadata"
    t.index ["session_id"], name: "index_conversations_on_session_id", unique: true
    t.index ["user_id"], name: "index_conversations_on_user_id"
  end

  create_table "messages", force: :cascade do |t|
    t.bigint "conversation_id", null: false
    t.text "content"
    t.string "role"
    t.jsonb "metadata"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index "conversation_id, ((metadata ->> 'original_message_id'::text))", name: "index_messages_unique_error_per_original", unique: true, where: "(((role)::text = 'assistant'::text) AND ((metadata ->> 'error'::text) = 'true'::text))"
    t.index ["conversation_id", "created_at"], name: "index_messages_on_conversation_and_created"
    t.index ["conversation_id", "role"], name: "index_messages_on_conversation_and_role"
    t.index ["conversation_id"], name: "index_messages_on_conversation_id"
    t.index ["created_at"], name: "index_messages_on_created_at"
    t.index ["metadata"], name: "index_messages_on_metadata", using: :gin
    t.index ["role"], name: "index_messages_on_role"
  end

  create_table "users", force: :cascade do |t|
    t.string "email"
    t.string "name"
    t.datetime "last_active_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "api_token"
    t.index ["api_token"], name: "index_users_on_api_token", unique: true
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  add_foreign_key "analyses", "conversations"
  add_foreign_key "conversations", "users"
  add_foreign_key "messages", "conversations"
end
