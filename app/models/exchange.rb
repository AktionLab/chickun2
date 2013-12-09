class Exchange < ActiveRecord::Base
  has_many :currency_pairs

  def client
    Client.const_get(key.classify).new
  end
end
