# This file is auto-generated from the current state of the database. Instead of editing this file, 
# please use the migrations feature of Active Record to incrementally modify your database, and
# then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your database schema. If you need
# to create the application database on another system, you should be using db:schema:load, not running
# all the migrations from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended to check this file into your version control system.

ActiveRecord::Schema.define(:version => 5) do

  create_table "artifacts", :force => true do |t|
    t.integer "gem_id"
    t.string  "type"
    t.string  "location"
  end

  create_table "event_handlers", :force => true do |t|
    t.integer "managed_gem_id"
    t.string  "event"
    t.string  "handler"
  end

  create_table "gem_search_criterias", :force => true do |t|
    t.string  "regex"
    t.integer "gem_source_id"
  end

  create_table "gem_sources", :force => true do |t|
    t.string "name"
    t.string "uri"
  end

  create_table "managed_gems", :force => true do |t|
    t.string  "name"
    t.string  "version"
    t.integer "gem_source_id"
  end

end
