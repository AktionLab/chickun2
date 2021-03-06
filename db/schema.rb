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
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20131112005123) do

  create_table "currency_pairs", force: true do |t|
    t.integer  "exchange_id"
    t.string   "name"
    t.string   "key"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "currency_pairs", ["exchange_id"], name: "index_currency_pairs_on_exchange_id"

  create_table "exchanges", force: true do |t|
    t.string   "name"
    t.string   "key"
    t.string   "website"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "trades", force: true do |t|
    t.integer  "exchange_id"
    t.integer  "currency_pair_id"
    t.integer  "trade_id"
    t.datetime "datetime"
    t.string   "trade_type"
    t.decimal  "price",            precision: 12, scale: 5
    t.decimal  "amount",           precision: 12, scale: 5
  end

  add_index "trades", ["currency_pair_id"], name: "index_trades_on_currency_pair_id"
  add_index "trades", ["exchange_id"], name: "index_trades_on_exchange_id"
  add_index "trades", ["trade_id"], name: "index_trades_on_trade_id"

end
