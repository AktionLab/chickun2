class CreateTrades < ActiveRecord::Migration
  def change
    create_table :trades do |t|
      t.references :exchange, index: true
      t.references :currency_pair, index: true
      t.integer :trade_id
      t.datetime :datetime
      t.string :trade_type
      t.decimal :price, precision: 12, scale: 5
      t.decimal :amount, precision: 12, scale: 5
      t.index [:trade_id]
    end
  end
end
