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
    client = Client::Btce.new BTCE_CONFIG['public_url'], BTCE_CONFIG['private_url']
    exchange = Exchange.where(key: 'btce').first
    pairs = exchange.currency_pairs
    while true do
      pairs.each do |pair|
        begin
          data = JSON.parse(client.pair_trade_history(pair.key), symbolize_names: true)
        rescue RuntimeError => e
          puts e.message
          next
        end
        new_trade_count = 0
        data.each do |trade|
          if !Trade.where(trade_id: trade[:tid]).exists?
            Trade.create(
              exchange:      exchange,
              currency_pair: pair,
              trade_id:      trade[:tid],
              datetime:      Time.at(trade[:date]),
              trade_type:    trade[:trade_type],
              price:         trade[:price],
              amount:        trade[:amount]
            )
            new_trade_count += 1
          end
        end
      end 
      puts "\n"
      sleep 10
    end
  end
end

