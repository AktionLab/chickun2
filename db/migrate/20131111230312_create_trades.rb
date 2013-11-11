class CreateTrades < ActiveRecord::Migration
  def change
    create_table :trades do |t|
      t.references :exchange, index: true
      t.references :currency_pair, index: true
      t.datetime :datetime
      t.string :type
      t.decimal :price
      t.decimal :amount

      t.timestamps
    end
  end
end
