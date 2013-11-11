class Trade < ActiveRecord::Base
  belongs_to :exchange
  belongs_to :currency_pair
end
