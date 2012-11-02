# encoding: UTF-8
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
# It's strongly recommended to check this file into your version control system.

ActiveRecord::Schema.define(:version => 20121102103209) do

  create_table "SpatialIndex", :id => false, :force => true do |t|
    t.text   "f_table_name"
    t.text   "f_geometry_column"
    t.binary "search_frame"
  end

  create_table "audits", :force => true do |t|
    t.integer  "auditable_id"
    t.string   "auditable_type"
    t.integer  "associated_id"
    t.string   "associated_type"
    t.integer  "user_id"
    t.string   "user_type"
    t.string   "username"
    t.string   "action"
    t.text     "audited_changes"
    t.integer  "version",         :default => 0
    t.string   "comment"
    t.string   "remote_address"
    t.datetime "created_at"
  end

  add_index "audits", ["associated_id", "associated_type"], :name => "associated_index"
  add_index "audits", ["auditable_id", "auditable_type"], :name => "auditable_index"
  add_index "audits", ["created_at"], :name => "index_audits_on_created_at"
  add_index "audits", ["user_id", "user_type"], :name => "user_index"

  create_table "funding_sources", :force => true do |t|
    t.string   "name"
    t.datetime "created_at", :null => false
    t.datetime "updated_at", :null => false
  end

  create_table "locations", :force => true do |t|
    t.string   "address_1"
    t.string   "address_2"
    t.string   "city"
    t.string   "state"
    t.string   "zip"
    t.datetime "created_at",                                          :null => false
    t.datetime "updated_at",                                          :null => false
    t.spatial  "position",   :limit => {:srid=>4326, :type=>"point"}
  end

  create_table "mobility_types", :force => true do |t|
    t.string "name"
    t.string "description"
  end

  create_table "open_capacities", :force => true do |t|
    t.integer  "service_id"
    t.integer  "seats_open"
    t.integer  "wheelchair_spaces_open"
    t.integer  "scooter_spaces_open"
    t.text     "notes"
    t.datetime "departure_time"
    t.integer  "departure_location_id"
    t.datetime "arrival_time"
    t.integer  "arrival_location_id"
    t.datetime "created_at",             :null => false
    t.datetime "updated_at",             :null => false
  end

  create_table "operating_hours", :force => true do |t|
    t.integer  "service_id"
    t.integer  "day_of_week"
    t.time     "open_time"
    t.time     "close_time"
    t.datetime "created_at",  :null => false
    t.datetime "updated_at",  :null => false
  end

  create_table "providers", :force => true do |t|
    t.string   "name"
    t.integer  "address_id"
    t.integer  "primary_contact_id"
    t.datetime "created_at",         :null => false
    t.datetime "updated_at",         :null => false
  end

  create_table "service_requests", :force => true do |t|
    t.integer  "trip_ticket_id"
    t.integer  "open_capacity_id"
    t.integer  "status"
    t.integer  "user_id"
    t.text     "notes"
    t.datetime "created_at",       :null => false
    t.datetime "updated_at",       :null => false
  end

  create_table "services", :force => true do |t|
    t.string   "name"
    t.integer  "provider_id"
    t.integer  "funding_source_id"
    t.datetime "created_at",                                                    :null => false
    t.datetime "updated_at",                                                    :null => false
    t.integer  "operating_hours_id"
    t.text     "rate"
    t.spatial  "service_area",       :limit => {:srid=>4326, :type=>"polygon"}
    t.hstore   "eligibility"
  end

  create_table "spatialite_history", :primary_key => "event_id", :force => true do |t|
    t.text "table_name",      :null => false
    t.text "geometry_column"
    t.text "event",           :null => false
    t.text "timestamp",       :null => false
    t.text "ver_sqlite",      :null => false
    t.text "ver_splite",      :null => false
  end

  create_table "trip_claims", :force => true do |t|
    t.integer  "origin_provider_id"
    t.integer  "claimant_provider_id"
    t.integer  "trip_ticket_id"
    t.integer  "status"
    t.datetime "created_at",           :null => false
    t.datetime "updated_at",           :null => false
    t.text     "rate"
    t.integer  "claimant_service_id"
  end

  create_table "trip_results", :force => true do |t|
    t.integer  "trip_ticket_id"
    t.integer  "trip_claim_id"
    t.integer  "outcome"
    t.time     "actual_pick_up_time"
    t.time     "actual_drop_off_time"
    t.integer  "rate_type"
    t.integer  "rate"
    t.integer  "driver_id"
    t.integer  "vehicle_type"
    t.integer  "vehicle_id"
    t.integer  "fare_type"
    t.integer  "base_fare"
    t.integer  "fare"
    t.float    "miles_travelled"
    t.float    "odometer_start"
    t.float    "odometer_end"
    t.float    "billable_mileage"
    t.string   "extra_securements_used"
    t.datetime "created_at",             :null => false
    t.datetime "updated_at",             :null => false
  end

  create_table "trip_tickets", :force => true do |t|
    t.integer  "origin_provider_id"
    t.integer  "origin_customer_id"
    t.integer  "claimant_provider_id"
    t.integer  "claimant_customer_id"
    t.integer  "approved_claim_id"
    t.boolean  "customer_information_withheld"
    t.date     "customer_dob"
    t.string   "customer_name"
    t.integer  "customer_address_id"
    t.string   "customer_primary_phone"
    t.string   "customer_emergency_phone"
    t.text     "customer_impairment_description"
    t.integer  "customer_boarding_time"
    t.integer  "customer_deboarding_time"
    t.integer  "customer_seats_required"
    t.text     "customer_notes"
    t.integer  "origin_trip_id"
    t.integer  "claimant_trip_id"
    t.integer  "pick_up_location_id"
    t.integer  "drop_off_location_id"
    t.time     "earliest_pick_up_time"
    t.time     "appointment_time"
    t.integer  "scheduling_priority"
    t.integer  "allowed_time_variance"
    t.integer  "num_attendants"
    t.integer  "num_guests"
    t.string   "trip_purpose_code"
    t.string   "trip_purpose_description"
    t.text     "trip_notes"
    t.datetime "created_at",                      :null => false
    t.datetime "updated_at",                      :null => false
    t.integer  "mobility_type_id"
  end

  create_table "users", :force => true do |t|
    t.string   "email"
    t.string   "name"
    t.string   "title"
    t.string   "phone"
    t.integer  "provider_id"
    t.datetime "created_at",  :null => false
    t.datetime "updated_at",  :null => false
  end

  create_table "waypoints", :force => true do |t|
    t.integer  "open_capacity_id"
    t.integer  "sequence_id"
    t.datetime "arrival_time"
    t.integer  "location_id"
    t.datetime "created_at",       :null => false
    t.datetime "updated_at",       :null => false
  end

end