class CreateExchanges < ActiveRecord::Migration
  def change
    create_table :exchanges do |t|
      t.string :name
      t.string :key
      t.string :website

      t.timestamps
    end
  end
end
