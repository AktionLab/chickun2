require 'httparty'
require 'openssl'
require 'json'
require 'pp'
require 'benchmark'
require 'typhoeus'
require 'bigdecimal'
require 'bigdecimal/util'

namespace :data do
  desc "Fetch public trade data for long term storage"
  task trade_history: :environment do
    client = Client::Btce.new
    exchange = Exchange.where(key: 'btce').first
    pairs = exchange.currency_pairs
    while true do
      pairs.each do |pair|
        data = client.pair_trade_history(pair.key)
        next if !data
        new_trades = data.take_while { |trade| !Trade.exists?(trade_id: trade[:tid]) }
        new_trades.each do |trade|
          Trade.create(
            exchange:      exchange,
            currency_pair: pair,
            trade_id:      trade[:tid],
            datetime:      Time.at(trade[:date]),
            trade_type:    trade[:trade_type],
            price:         trade[:price],
            amount:        trade[:amount]
          )
        end
      end 
      sleep 10
    end
  end
end

