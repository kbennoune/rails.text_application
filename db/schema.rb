# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20190107223028) do

  create_table "application_phone_numbers", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin" do |t|
    t.string "name"
    t.string "number"
    t.string "national_number"
    t.string "state"
    t.string "city"
    t.string "price"
    t.string "remote_application"
    t.string "remote_application_id"
    t.string "remote_created_at"
    t.string "remote_service"
    t.string "geohash"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "remote_id"
    t.string "remote_number_state"
  end

  create_table "archived_weather_conditions", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4" do |t|
    t.date "date"
    t.string "time_of_day"
    t.string "station"
    t.string "city"
    t.string "state"
    t.string "postal_code"
    t.decimal "latitude", precision: 4, scale: 2
    t.decimal "longitude", precision: 5, scale: 2
    t.boolean "observed"
    t.string "condition"
    t.decimal "high", precision: 4, scale: 1
    t.decimal "low", precision: 4, scale: 1
    t.decimal "avg", precision: 4, scale: 1
    t.decimal "app_high", precision: 4, scale: 1
    t.decimal "app_low", precision: 4, scale: 1
    t.decimal "precip_prob", precision: 3
    t.decimal "precip_mm", precision: 6, scale: 1
    t.decimal "snow_mm", precision: 6, scale: 1
    t.decimal "humidity", precision: 3
    t.decimal "wind_spd", precision: 4, scale: 1
    t.string "condition_code"
    t.string "request_url"
    t.text "raw_data"
    t.datetime "forecast_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "authenticate_subscription_codes", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin" do |t|
    t.bigint "subscription_id"
    t.string "mobile"
    t.string "code"
    t.datetime "expires_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["subscription_id"], name: "index_authenticate_subscription_codes_on_subscription_id"
  end

  create_table "authentication_codes", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin" do |t|
    t.bigint "person_id"
    t.string "code"
    t.datetime "expires_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["person_id"], name: "index_authentication_codes_on_person_id"
  end

  create_table "authorized_managed_facebook_places", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin" do |t|
    t.bigint "facebook_place_id"
    t.string "manager_email"
    t.bigint "created_by_user_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_by_user_id"], name: "index_authorized_managed_facebook_places_on_created_by_user_id"
    t.index ["facebook_place_id"], name: "index_authorized_managed_facebook_places_on_facebook_place_id"
    t.index ["manager_email"], name: "index_authorized_managed_facebook_places_on_manager_email"
  end

  create_table "business_admins", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin" do |t|
    t.bigint "business_id"
    t.bigint "person_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["business_id"], name: "index_business_admins_on_business_id"
    t.index ["person_id"], name: "index_business_admins_on_person_id"
  end

  create_table "businesses", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin" do |t|
    t.string "name"
    t.bigint "facebook_place_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["facebook_place_id"], name: "index_businesses_on_facebook_place_id"
  end

  create_table "channel_groups", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin" do |t|
    t.bigint "channel_id"
    t.bigint "text_group_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["channel_id"], name: "index_channel_groups_on_channel_id"
    t.index ["text_group_id"], name: "index_channel_groups_on_text_group_id"
  end

  create_table "channel_people", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin" do |t|
    t.bigint "person_id"
    t.bigint "channel_id"
    t.boolean "inactive"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "application_phone_number_id"
    t.bigint "added_from_text_group_id"
    t.index ["added_from_text_group_id"], name: "index_channel_people_on_added_from_text_group_id"
    t.index ["application_phone_number_id"], name: "index_channel_people_on_application_phone_number_id"
    t.index ["channel_id", "person_id"], name: "index_channel_people_on_channel_id_and_person_id", unique: true
    t.index ["channel_id"], name: "index_channel_people_on_channel_id"
    t.index ["person_id"], name: "index_channel_people_on_person_id"
  end

  create_table "channels", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin" do |t|
    t.string "topic"
    t.bigint "business_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "started_by_person_id"
    t.index ["business_id"], name: "index_channels_on_business_id"
    t.index ["started_by_person_id"], name: "index_channels_on_started_by_person_id"
  end

  create_table "identities", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin" do |t|
    t.string "provider"
    t.string "uid"
    t.string "name"
    t.string "oauth_token"
    t.datetime "oauth_expires_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.text "scopes"
    t.string "oauth_refresh_token"
    t.string "email"
    t.index ["user_id"], name: "index_identities_on_user_id"
  end

  create_table "people", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin" do |t|
    t.bigint "user_id"
    t.string "name"
    t.string "mobile"
    t.string "phone"
    t.string "photo"
    t.string "timezone"
    t.string "email"
    t.text "vcard"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "preferred_language"
    t.index ["user_id"], name: "index_people_on_user_id"
  end

  create_table "person_aliases", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin" do |t|
    t.bigint "real_id"
    t.bigint "alias_id"
    t.string "status"
    t.index ["alias_id"], name: "index_person_aliases_on_alias_id"
    t.index ["real_id"], name: "index_person_aliases_on_real_id"
  end

  create_table "service_invitations", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin" do |t|
    t.string "code"
    t.string "fufillment_type"
    t.string "service_location_type"
    t.bigint "service_location_id"
    t.text "service_groups"
    t.datetime "expires_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "inviting_person_id"
    t.bigint "invited_person_id"
    t.index ["invited_person_id"], name: "index_service_invitations_on_invited_person_id"
    t.index ["inviting_person_id"], name: "index_service_invitations_on_inviting_person_id"
    t.index ["service_location_type", "service_location_id"], name: "index_service_invitations_on_polymorphic_service_location"
  end

  create_table "subscriptions", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin" do |t|
    t.string "product_identifier"
    t.string "transaction_identifier"
    t.string "transaction_receipt"
    t.string "transaction_date"
    t.bigint "business_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["business_id"], name: "index_subscriptions_on_business_id"
  end

  create_table "text_group_people", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin" do |t|
    t.bigint "person_id"
    t.bigint "text_group_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["person_id"], name: "index_text_group_people_on_person_id"
    t.index ["text_group_id"], name: "index_text_group_people_on_text_group_id"
  end

  create_table "text_groups", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin" do |t|
    t.string "name"
    t.bigint "business_id"
    t.bigint "created_by_person_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["business_id"], name: "index_text_groups_on_business_id"
    t.index ["created_by_person_id"], name: "index_text_groups_on_created_by_person_id"
  end

  create_table "text_messages", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin" do |t|
    t.string "app_status"
    t.string "app_direction"
    t.datetime "send_at"
    t.bigint "channel_id"
    t.string "direction"
    t.string "type"
    t.datetime "time"
    t.text "times"
    t.string "description"
    t.text "to"
    t.string "message_id"
    t.string "message_owner"
    t.string "message_time"
    t.string "message_direction"
    t.text "message_to"
    t.string "message_from"
    t.text "message_text"
    t.string "message_applicationId"
    t.text "message_media"
    t.string "message_tag"
    t.string "message_segmentCount"
    t.text "remote_headers"
    t.text "remote_body"
    t.datetime "remote_request_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "original_message_from"
    t.string "remote_state"
    t.datetime "remote_sending_time"
    t.datetime "remote_sent_time"
    t.text "remote_events"
    t.text "message_generator_keys"
    t.bigint "responding_to_text_message_id"
    t.string "header_addendum_key"
    t.bigint "sender_id"
    t.bigint "original_sender_id"
    t.boolean "hide_header_description"
    t.string "message_generator_key"
    t.string "to_people"
    t.index ["channel_id"], name: "index_text_messages_on_channel_id"
    t.index ["original_sender_id"], name: "index_text_messages_on_original_sender_id"
    t.index ["responding_to_text_message_id"], name: "index_text_messages_on_responding_to_text_message_id"
    t.index ["sender_id"], name: "index_text_messages_on_sender_id"
  end

  create_table "topic_group_people", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin" do |t|
    t.bigint "person_id"
    t.bigint "topic_group_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["person_id"], name: "index_topic_group_people_on_person_id"
    t.index ["topic_group_id"], name: "index_topic_group_people_on_topic_group_id"
  end

  create_table "topic_groups", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin" do |t|
    t.bigint "business_id"
    t.string "topic"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["business_id"], name: "index_topic_groups_on_business_id"
  end

  create_table "trigrams", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin" do |t|
    t.string "trigram", limit: 3
    t.integer "score", limit: 2
    t.integer "owner_id"
    t.string "owner_type"
    t.string "fuzzy_field"
    t.index ["owner_id", "owner_type", "fuzzy_field", "trigram", "score"], name: "index_for_match"
    t.index ["owner_id", "owner_type"], name: "index_by_owner"
  end

  create_table "users", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin" do |t|
    t.string "mobile"
    t.string "email"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  add_foreign_key "authenticate_subscription_codes", "subscriptions"
  add_foreign_key "authentication_codes", "people"
  add_foreign_key "business_admins", "businesses"
  add_foreign_key "business_admins", "people"
  add_foreign_key "businesses", "facebook_places"
  add_foreign_key "channel_groups", "channels"
  add_foreign_key "channel_groups", "text_groups"
  add_foreign_key "channel_people", "application_phone_numbers"
  add_foreign_key "channel_people", "channels"
  add_foreign_key "channel_people", "people"
  add_foreign_key "channel_people", "text_groups", column: "added_from_text_group_id"
  add_foreign_key "channels", "people", column: "started_by_person_id"
  add_foreign_key "people", "users"
  add_foreign_key "person_aliases", "people", column: "alias_id"
  add_foreign_key "person_aliases", "people", column: "real_id"
  add_foreign_key "service_invitations", "people", column: "invited_person_id"
  add_foreign_key "text_group_people", "people"
  add_foreign_key "text_group_people", "text_groups"
  add_foreign_key "text_groups", "businesses"
  add_foreign_key "text_groups", "people", column: "created_by_person_id"
  add_foreign_key "text_messages", "channels"
  add_foreign_key "text_messages", "people", column: "original_sender_id"
  add_foreign_key "text_messages", "people", column: "sender_id"
  add_foreign_key "topic_group_people", "people"
  add_foreign_key "topic_group_people", "topic_groups"
end
