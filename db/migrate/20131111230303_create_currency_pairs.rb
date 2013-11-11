class CreateCurrencyPairs < ActiveRecord::Migration
  def change
    create_table :currency_pairs do |t|
      t.references :exchange, index: true
      t.string :name
      t.string :key

      t.timestamps
    end
  end
end
