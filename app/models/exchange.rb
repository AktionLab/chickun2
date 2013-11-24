class Exchange < ActiveRecord::Base
  has_many :currency_pairs
end
