require 'httparty'
require 'openssl'
require 'json'
require 'pp'
require 'benchmark'
require 'typhoeus'
require 'bigdecimal'
require 'bigdecimal/util'

@nonce_val = 4000

@nonce1 = 1
@nonce2 = 1
@nonce3 = 1

@trade_rur = false

StaleLog = Logger.new(File.expand_path(File.join(__FILE__, '/../../../log/stale.log')))
ErrorLog = Logger.new(File.expand_path(File.join(__FILE__, '/../../../log/error.log')))

namespace :chickun do
  desc "Pull in data from BTC-e"
  task :feed => :environment do
    puts "Chickun Eat!!!"

    redis = Redis.new

    btce = Client::Btce.new 'https://btc-e.com/api/2'

    while true
      ticker = btce.ticker(*Currency.pairs)
      redis.mset(*ticker.map{|k,v| ["ticker_#{k}",v]}.flatten)
    end
  end

  desc "Test BTC-e API method: getInfo()"
  task :trade_history => :environment do
    # Example response:
    # {
    #   "success"=>1,
    #   "return"=>{
    #     "3724293"=>{
    #       "pair"=>"ltc_btc",
    #       "type"=>"buy",
    #       "amount"=>3.29924,
    #       "rate"=>0.03031,
    #       "order_id"=>12631143,
    #       "is_your_order"=>0,
    #       "timestamp"=>1368039389
    #     },
    #   }
    # }
    options = {
      :count => 2 
    }
    puts btce_query("TradeHistory", options)
  end
  
  task :flap => :environment do
    puts "Chickun Arise!!!" 

    @client = Client::Btce.new(BTCE_CONFIG['public_url'],BTCE_CONFIG['private_url'])
    
    @key1    = BTCE_CONFIG['key1'];
    @secret1 = BTCE_CONFIG['secret1']; 
    @key2    = BTCE_CONFIG['key2'];
    @secret2 = BTCE_CONFIG['secret2']; 
    @key3    = BTCE_CONFIG['key3'];
    @secret3 = BTCE_CONFIG['secret3']; 

    # build request
    options = {
      :method => 'TradeHistory',
      :count  => 10,
      :order  => 'DESC',
      :pair   => 'ftc_btc',
    }
    
    last_vol = 0
    last = 0
    avg = 0
    fee = 0.002
    start_usd = 2
    start_rur = 340
    start_btc = 0.1
    start_btc_rur = 0.1
    min_profit = 0.0
    time_to_stale = 3
    while true do
      usd = 2.0
      rur = 340
      btc = 0.1
      ltc = 0.0

      start_data_time = Time.now.to_f
      
      begin
        res = @client.pub_api_request('ticker',[['btc','usd'],['ltc','btc'],['ltc','usd']]) 
        ltc_btc_res = res["ltc_btc"]["ticker"]
        ltc_usd_res = res["ltc_usd"]['ticker']
        btc_usd_res = res["btc_usd"]['ticker']
      rescue Exception => e
        ErrorLog.info(e.inspect)
        puts e.inspect
        retry
      end

      pull_duration = Time.now.to_f - start_data_time
      puts "Data Pull Time: #{pull_duration}"
      if pull_duration > time_to_stale
        puts "Stale data...skipping"
        next
      end

      # values of cryptos in USD based on current buy or sell price,
      # depending on whether you're going in our out of USD
      btc_per_usd_buy  = btc_usd_res["buy"].to_d
      ltc_per_usd_buy  = ltc_usd_res["buy"].to_d
      ltc_per_usd_sell = ltc_usd_res["sell"].to_d
      btc_per_usd_sell = btc_usd_res["sell"].to_d

      ltc_per_btc_buy  = ltc_btc_res["buy"].to_d
      ltc_per_btc_sell = ltc_btc_res["sell"].to_d

      #-----------------------------------------
      # Trade BTC forward (BLUB)
      #-----------------------------------------

      # simulate trade, account for fees
      # sell BTC for USD
      ltc            = (btc/ltc_per_btc_buy).round(8)
      ltc_after_fees = (ltc - (ltc*fee).round(8))
      usd            = (ltc_after_fees*ltc_per_usd_sell).round(8)
      usd_after_fees = (usd - (usd*fee).round(8)).round(8)
      btc            = (usd_after_fees/btc_per_usd_buy).round(8)
      btc_after_fees = (btc - (btc*fee).round(8)).round(8)
      
      # calculate profit
      profit = ((btc_after_fees - start_btc) / start_btc * 100).round(2)
      puts "BTC (Forward): #{btc_after_fees}\t\tProfit: #{profit}%"
      
      # if profitable, TRADE!
      if profit > min_profit
        puts "Arise Chickun!!!"
        puts profit
        btc = @client.smallest_amount_available_in_btc('forward')
        next if btc < 0.02
        ltc            = (btc/ltc_per_btc_buy).round(8)
        ltc_after_fees = (ltc - (ltc*fee).round(8))
        usd            = (ltc_after_fees*ltc_per_usd_sell).round(8)
        usd_after_fees = (usd - (usd*fee).round(8)).round(8)
        btc            = (usd_after_fees/btc_per_usd_buy).round(8)
        btc_after_fees = (btc - (btc*fee).round(8)).round(8)
        @client.buy('btc_usd', btc, btc_per_usd_buy)       
        @client.buy('ltc_btc', ltc, ltc_per_btc_buy)
        @client.sell('ltc_usd', ltc_after_fees, ltc_per_usd_sell)
        
        options = {
          "rate_usd_btc" => btc_per_usd_buy,
          "amount_btc_buy" => btc,
          "rate_ltc_btc" => ltc_per_btc_buy,
          "amount_ltc_buy" => ltc,
          "rate_ltc_usd" => ltc_per_usd_sell,
          "amount_ltc_sell" => ltc_after_fees
        }
        #trade_btc_forward options
        #check_balance
      end
 
      #-----------------------------------------
      # Trade BTC backward (BULB)
      #-----------------------------------------

      # reset
      usd = 2.0
      btc = 0.1
      start_btc = 0.1
      rur = 340
      ltc = 0.0
 
      # account for fees
      usd            = (btc*btc_per_usd_sell).round(8)
      usd_after_fees = (usd - (usd*fee).round(8)).round(8)
      ltc            = (usd_after_fees/ltc_per_usd_buy).round(8)
      ltc_after_fees = (ltc - (ltc*fee).round(8)).round(8)
      btc2           = (ltc_after_fees*ltc_per_btc_sell).round(8)
      btc_after_fees = (btc2 - (btc2*fee).round(8)).round(8)
       
      # calculate profit
      profit = ((btc_after_fees - start_btc) / start_btc * 100).round(2)
      puts "BTC (Backward): #{btc_after_fees}\t\tProfit: #{profit}%"

      # if profitable, TRADE!
      if profit > min_profit
        puts "Arise Chickun!!!"
        
        btc = @client.smallest_amount_available_in_btc('backward')
        next if btc < 0.02
        
        usd            = (btc*btc_per_usd_sell).round(8)
        usd_after_fees = (usd - (usd*fee).round(8)).round(8)
        ltc            = (usd_after_fees/ltc_per_usd_buy).round(8)
        ltc_after_fees = (ltc - (ltc*fee).round(8)).round(8)
        btc2           = (ltc_after_fees*ltc_per_btc_sell).round(8)
        btc_after_fees = (btc2 - (btc2*fee).round(8)).round(8)
  
        @client.buy('ltc_usd', ltc, ltc_per_usd_buy)       
        @client.sell('ltc_btc', ltc_after_fees, ltc_per_btc_sell)
        @client.sell('btc_usd', btc2, btc_per_usd_sell)


        options = {
          "rate_usd_ltc" => ltc_per_usd_buy,
          "amount_ltc_buy" => ltc,
          "rate_ltc_btc" => ltc_per_btc_sell,
          "amount_ltc_sell" => ltc_after_fees,
          "rate_btc_usd" => btc_per_usd_sell,
          "amount_btc_sell" => btc
        }
        #trade_btc_backward options
        #check_balance
      end

      if @trade_rur == true 
      #-----------------------------------------
      # Trade BTC forward (BLUB) RUR
      #-----------------------------------------
      btc_rur = Net::HTTP.get_response URI('https://btc-e.com/api/2/btc_rur/ticker')
      ltc_rur = Net::HTTP.get_response URI('https://btc-e.com/api/2/ltc_rur/ticker')

      btc_rur_res = JSON.parse(btc_rur.body)["ticker"]
      ltc_btc_res = JSON.parse(ltc_btc.body)["ticker"]
      ltc_rur_res = JSON.parse(ltc_rur.body)["ticker"]
      ltc_btc = Net::HTTP.get_response URI('https://btc-e.com/api/2/ltc_btc/ticker')

      # values of cryptos in USD based on current buy or sell price,
      # depending on whether you're going in our out of USD
      btc_per_rur_buy  = btc_rur_res["buy"].to_f
      ltc_per_rur_buy  = ltc_rur_res["buy"].to_f
      ltc_per_rur_sell = ltc_rur_res["sell"].to_f
      btc_per_rur_sell = btc_rur_res["sell"].to_f

      ltc_per_btc_buy  = ltc_btc_res["buy"].to_f
      ltc_per_btc_sell = ltc_btc_res["sell"].to_f


      # reset
      rur = 340
      btc = 0.1
      ltc = 0.0

      # simulate trade, account for fees
      # sell BTC for RUR
      ltc            = (btc/ltc_per_btc_buy).round(8)
      ltc_after_fees = (ltc - (ltc*fee).round(8))
      rur            = (ltc_after_fees*ltc_per_rur_sell).round(8)
      rur_after_fees = (rur - (rur*fee).round(8)).round(8)
      btc            = (rur_after_fees/btc_per_rur_buy).round(8)
      btc_after_fees = (btc - (btc*fee).round(8)).round(8)
      
      # calculate profit
      profit = ((btc_after_fees - start_btc_rur) / start_btc_rur * 100).round(2)
      puts "BTC (RUR Forward): #{btc_after_fees}\t\tProfit: #{profit}%"
      
      # if profitable, TRADE!
      if profit > min_profit
        puts "Arise Chickun!!!"
        options = {
          "rate_rur_btc" => btc_per_rur_buy,
          "amount_btc_buy" => btc,
          "rate_ltc_btc" => ltc_per_btc_buy,
          "amount_ltc_buy" => ltc,
          "rate_ltc_rur" => ltc_per_rur_sell,
          "amount_ltc_sell" => ltc_after_fees
        }
        #trade_btc_forward_rur options
        check_balance
      end
 
      #-----------------------------------------
      # Trade BTC backward (BULB) RUR
      #-----------------------------------------

      # reset
      rur = 340
      btc = 0.1
      ltc = 0.0
 
      # account for fees
      rur            = (btc*btc_per_rur_sell).round(8)
      rur_after_fees = (rur - (rur*fee).round(8)).round(8)
      ltc            = (rur_after_fees/ltc_per_rur_buy).round(8)
      ltc_after_fees = (ltc - (ltc*fee).round(8)).round(8)
      btc2           = (ltc_after_fees*ltc_per_btc_sell).round(8)
      btc_after_fees = (btc2 - (btc2*fee).round(8)).round(8)
       
      # calculate profit
      profit = ((btc_after_fees - start_btc_rur) / start_btc_rur * 100).round(2)
      puts "BTC (RUR Backward): #{btc_after_fees}\t\tProfit: #{profit}%"

      # if profitable, TRADE!
      if profit > min_profit
        puts "Arise Chickun!!!"
        options = {
          "rate_rur_ltc" => ltc_per_rur_buy,
          "amount_ltc_buy" => ltc,
          "rate_ltc_btc" => ltc_per_btc_sell,
          "amount_ltc_sell" => ltc_after_fees,
          "rate_btc_rur" => btc_per_rur_sell,
          "amount_btc_sell" => btc
        }
        #trade_btc_backward_rur options
        check_balance
      end
      end
      #-----------------------------------------
      # Trade USD forward
      #-----------------------------------------

      # reset
      usd = 2.0
      rur = 340
      btc = 0.02
      ltc = 0.0

      # account for fees
      btc            = (usd/btc_per_usd_buy).round(8)
      btc_after_fees = (btc - (btc*fee).round(8)).round(8)
      ltc            = (btc_after_fees/ltc_per_btc_buy).round(8)
      ltc_after_fees = (ltc - (ltc*fee).round(8))
      usd            = (ltc_after_fees*ltc_per_usd_sell).round(8)
      usd_after_fees = (usd - (usd*fee).round(8)).round(8)

      # calculate profit
      profit = ((usd_after_fees - start_usd) / start_usd * 100).round(2)
      #puts "USD (Forward): #{usd_after_fees}\t\tProfit: #{profit}%"
      
      # if profitable, TRADE!
      if profit > min_profit
        #puts "Arise Chickun!!!"
        options = {
          "rate_usd_btc" => btc_per_usd_buy,
          "amount_btc_buy" => btc,
          "rate_ltc_btc" => ltc_per_btc_buy,
          "amount_ltc_buy" => ltc,
          "rate_ltc_usd" => ltc_per_usd_sell,
          "amount_ltc_sell" => ltc_after_fees
        }
        #trade_usd_forward options
        #check_balance
      end
 
      #-----------------------------------------
      # Trade USD backward
      #-----------------------------------------

      # reset
      usd = 2.0
      rur = 340
      btc = 0.02
      ltc = 0.0
 
      # account for fees
      ltc            = (usd/ltc_per_usd_buy).round(8)
      ltc_after_fees = (ltc - (ltc*fee).round(8)).round(8)
      btc            = (ltc_after_fees*ltc_per_btc_sell).round(8)
      btc_after_fees = (btc - (btc*fee).round(8)).round(8)
      usd            = (btc_after_fees*btc_per_usd_sell).round(8)
      usd_after_fees = (usd - (usd*fee).round(8)).round(8)
 
      # calculate profit
      profit = ((usd_after_fees - start_usd) / start_usd * 100).round(2)
      #puts "USD (Backward): #{usd_after_fees}\t\tProfit: #{profit}%"

      # if profitable, TRADE!
      if profit > min_profit
        #puts "Arise Chickun!!!"
        options = {
          "rate_usd_ltc" => ltc_per_usd_buy,
          "amount_ltc_buy" => ltc,
          "rate_ltc_btc" => ltc_per_btc_sell,
          "amount_ltc_sell" => ltc_after_fees,
          "rate_btc_usd" => btc_per_usd_sell,
          "amount_btc_sell" => btc_after_fees
        }
        #trade_usd_backward options
        #check_balance
      end

      #-----------------------------------------
      # Trade RUR forward
      #-----------------------------------------

      rur = 340
      btc = 0.0
      ltc = 0.0
 
      #btc = rur / btc_rur_res["buy"].to_f.round(5)
      #btc -= (btc*fee).round(5)
      #ltc = btc / ltc_btc_res["buy"].to_f.round(5)
      #ltc -= (ltc*fee).round(5)
      #rur = ltc_rur_res["sell"].to_f.round(5) * ltc
      #rur -= (rur*fee).round(5)

      #profit = ((rur - start_rur) / start_rur * 100).round(2)
      #puts "RUR (Forward): #{rur.round(8)}\t\tProfit: #{profit}%"
     
      #-----------------------------------------
      # Trade RUR backward
      #-----------------------------------------

      rur = 340
      btc = 0.0
      ltc = 0.0
 
      #ltc = rur / ltc_rur_res["buy"].to_f.round(5)
      #ltc -= (ltc*fee).round(5)
      #btc = ltc*ltc_btc_res["buy"].to_f.round(5)
      #btc -= (btc*fee).round(5)
      #rur = btc_rur_res["sell"].to_f.round(5) * btc
      #rur -= (rur*fee).round(5)
 
      #profit = ((rur - start_rur) / start_rur * 100).round(2)
      #puts "RUR (Backward): #{rur.round(8)}\tProfit: #{profit}%\n\n"
 
      #if last_vol != ticker["vol"]
      #  avg += ((ticker["last"].to_f - avg)*1/(i+1))
      #  puts "Last: #{ticker["last"]}\tAvg (100): #{avg}"
      #  last_vol = ticker["vol"]
      #end

      sleep 1
    end
    #puts btce_query(options)
  end

def btce_query(method, options={})
  uri = URI(BTCE_CONFIG['private_url'])
  req = Net::HTTP::Post.new uri
  @nonce_val += 1
  req.set_form_data(options.merge :method => method, :nonce => (Time.now.to_i + @nonce_val))
  puts req.body
  sign = OpenSSL::HMAC::hexdigest('sha512', BTCE_CONFIG['trade_secret'], req.body) 

  req["Key"] = BTCE_CONFIG['trade_key']
  req["Sign"] = sign
  req["User-Agent"] = "Chickun 0.1"

  #puts options.inspect
  res = Net::HTTP.start(uri.hostname, uri.port, :use_ssl => true) do |http|
    http.request(req)
  end
  puts res.body
  JSON.parse(res.body)
end

def make_trade(options)
  begin
    response = btce_query("Trade",options)
    if response['success'] != 1
      StaleLog.info("ERROR")
    elsif response['return']['remains'] == 0
      StaleLog.info("OK")
    else
      StaleLog.info("STALE")
    end
    puts response.inspect
  end while response["success"] != 1 
end

def check_balance
  options = {}
  res = @client.account_info 
  puts "USD funds: #{res["return"]["funds"]["usd"]}"
  puts "BTC funds: #{res["return"]["funds"]["btc"]}"
  puts "LTC funds: #{res["return"]["funds"]["ltc"]}"
  if res["return"]["funds"]["btc"].to_f < 0.02
    puts "Abort: Fontas is pumping BTC!!"
    abort
  elsif res["return"]["funds"]["ltc"].to_f < 0.75
    puts "Abort: LTC too low!"
    abort
  elsif res["return"]["funds"]["rur"].to_f < 340
    @trade_rur = false
  end
end

def build_trade_query(key, secret, nonce, options = {})
  #@nonce_val += 1
  uri = URI(BTCE_CONFIG['private_url'])
  req = Net::HTTP::Post.new uri
  req.set_form_data(options.merge :method => "Trade", :nonce => nonce)#(Time.now.to_i + @nonce_val))
  sign = OpenSSL::HMAC::hexdigest('sha512', secret, req.body) 
   
  request = Typhoeus::Request.new(
    BTCE_CONFIG['url'],
    method:        :post,
    body:          req.body,
    headers:       {"Key" => key, "Sign" => sign, "User-Agent" => "Chickun 0.1"},
  )
end

def nonce1
  @nonce1 += 1
  Time.now.to_i + @nonce1
end

def nonce2
  @nonce2 += 1
  Time.now.to_i + @nonce2
end

def nonce3
  @nonce3 += 1
  Time.now.to_i + @nonce3
end

def trade_btc_forward(options={})
  options_usd_btc = {
    pair: "btc_usd",
    type: "buy",
    rate: options["rate_usd_btc"],
    amount: options["amount_btc_buy"]
  }
  options_btc_ltc = {
    pair: "ltc_btc",
    type: "buy",
    rate: options["rate_ltc_btc"],
    amount: options["amount_ltc_buy"]
  }
  options_ltc_usd = {
    pair: "ltc_usd",
    type: "sell",
    rate: options["rate_ltc_usd"],
    amount: options["amount_ltc_sell"]
  }

  begin
    usd_btc_req = build_trade_query(@key1, @secret1, nonce1, options_usd_btc)
    btc_ltc_req = build_trade_query(@key2, @secret2, nonce2, options_btc_ltc)
    ltc_usd_req = build_trade_query(@key3, @secret3, nonce3, options_ltc_usd)

    hydra = Typhoeus::Hydra.new
    hydra.queue(usd_btc_req)
    hydra.queue(btc_ltc_req)
    hydra.queue(ltc_usd_req)
    hydra.run

    puts JSON.parse(usd_btc_req.response.body)
    puts JSON.parse(btc_ltc_req.response.body)
    puts JSON.parse(ltc_usd_req.response.body)
  rescue Exception => e
    ErrorLog.info(e.inspect)
    puts e.inspect
  end
  
  #make_trade(options_btc_ltc)
  #make_trade(options_ltc_usd)
  #make_trade(options_usd_btc)
end

def trade_btc_backward(options={})
  options_usd_ltc = {
    pair: "ltc_usd",
    type: "buy",
    rate: options["rate_usd_ltc"],
    amount: options["amount_ltc_buy"]
  }
  options_ltc_btc = {
    pair: "ltc_btc",
    type: "sell",
    rate: options["rate_ltc_btc"],
    amount: options["amount_ltc_sell"]
  }
  options_btc_usd = {
    pair: "btc_usd",
    type: "sell",
    rate: options["rate_btc_usd"],
    amount: options["amount_btc_sell"]
  }
  
  begin
    usd_ltc_req = build_trade_query(@key1, @secret1, nonce1, options_usd_ltc)
    ltc_btc_req = build_trade_query(@key2, @secret2, nonce2, options_ltc_btc)
    btc_usd_req = build_trade_query(@key3, @secret3, nonce3, options_btc_usd)

    hydra = Typhoeus::Hydra.new
    hydra.queue(usd_ltc_req)
    hydra.queue(ltc_btc_req)
    hydra.queue(btc_usd_req)
    hydra.run

    puts JSON.parse(usd_ltc_req.response.body)
    puts JSON.parse(ltc_btc_req.response.body)
    puts JSON.parse(btc_usd_req.response.body)
  rescue Exception => e
    ErrorLog.info(e.inspect)
    puts e.inspect
  end

  #make_trade(options_btc_usd)
  #make_trade(options_usd_ltc)
  #make_trade(options_ltc_btc)
end

def trade_btc_forward_rur(options={})
  options_usd_btc = {
    pair: "btc_rur",
    type: "buy",
    rate: options["rate_rur_btc"],
    amount: options["amount_btc_buy"]
  }
  options_btc_ltc = {
    pair: "ltc_btc",
    type: "buy",
    rate: options["rate_ltc_btc"],
    amount: options["amount_ltc_buy"]
  }
  options_ltc_rur = {
    pair: "ltc_usd",
    type: "sell",
    rate: options["rate_ltc_rur"],
    amount: options["amount_ltc_sell"]
  }
  begin
    res = btce_query("Trade",options_btc_ltc)
    puts res.inspect
  end while res["success"] != 1 
  begin
    res = btce_query("Trade",options_ltc_rur)
    puts res.inspect
  end while res["success"] != 1
  begin
    res = btce_query("Trade",options_rur_btc) 
    puts res.inspect
  end while res["success"] != 1
end

def trade_btc_backward_rur(options={})
  options_rur_ltc = {
    pair: "ltc_rur",
    type: "buy",
    rate: options["rate_rur_ltc"],
    amount: options["amount_ltc_buy"]
  }
  options_ltc_btc = {
    pair: "ltc_btc",
    type: "sell",
    rate: options["rate_ltc_btc"],
    amount: options["amount_ltc_sell"]
  }
  options_btc_rur = {
    pair: "btc_rur",
    type: "sell",
    rate: options["rate_btc_rur"],
    amount: options["amount_btc_sell"]
  }
  begin
    res = btce_query("Trade",options_btc_rur)
  end while res["success"] != 1
  begin 
    res = btce_query("Trade",options_rur_ltc)
  end while res["success"] != 1
  begin
    res = btce_query("Trade",options_ltc_btc)
  end while res["success"] != 1
end

def trade_usd_forward(options={})
  options_usd_btc = {
    pair: "btc_usd",
    type: "buy",
    rate: options["rate_usd_btc"],
    amount: options["amount_btc_buy"]
  }
  options_btc_ltc = {
    pair: "ltc_btc",
    type: "buy",
    rate: options["rate_ltc_btc"],
    amount: options["amount_ltc_buy"]
  }
  options_ltc_usd = {
    pair: "ltc_usd",
    type: "sell",
    rate: options["rate_ltc_usd"],
    amount: options["amount_ltc_sell"]
  }
  begin
    res = btce_query("Trade",options_btc_ltc)
    puts res.inspect
  end while res["success"] != 1 
  begin
    res = btce_query("Trade",options_ltc_usd)
    puts res.inspect
  end while res["success"] != 1
  begin
    res = btce_query("Trade",options_usd_btc) 
    puts res.inspect
  end while res["success"] != 1
end

def trade_usd_backward(options={})
  options_usd_ltc = {
    pair: "ltc_usd",
    type: "buy",
    rate: options["rate_usd_ltc"],
    amount: options["amount_ltc_buy"]
  }
  options_ltc_btc = {
    pair: "ltc_btc",
    type: "sell",
    rate: options["rate_ltc_btc"],
    amount: options["amount_ltc_sell"]
  }
  options_btc_usd = {
    pair: "btc_usd",
    type: "sell",
    rate: options["rate_btc_usd"],
    amount: options["amount_btc_sell"]
  }
  begin
    res = btce_query("Trade",options_btc_usd)
  end while res["success"] != 1
  begin 
    res = btce_query("Trade",options_usd_ltc)
  end while res["success"] != 1
  begin
    res = btce_query("Trade",options_ltc_btc)
  end while res["success"] != 1
end
end
