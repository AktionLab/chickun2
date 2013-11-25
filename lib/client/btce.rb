module Client
  class Btce
    BUY  = 'buy'
    SELL = 'sell'
    PENDING = 'pending fulfillment'
    PARTIALLY_FILLED = 'partially fufilled'
    FILLED = 'fulfilled'

    def initialize
      @redis = Redis.new
      @redis.set("btce_nonce", Time.now.to_i + 3000000).to_i
    end

    def request(pair, operation)
      uri = URI.parse "#{BTCE_CONFIG['public_url']}/#{pair}/#{operation}"
      http = Net::HTTP.new uri.host, uri.port
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      request = Net::HTTP::Get.new uri.request_uri
      response = http.request request
      JSON.parse(response.body, symbolize_names: true)
    end

    def pair_ticker(pair)
      request(pair, 'ticker')
    end

    def pair_trade_history(pair)
      request(pair, 'trades')
    end

    def pub_api_request(type, pairs)
      requests  = []
      hydra = Typhoeus::Hydra.new

      pairs.each do |pair|
        requests << Typhoeus::Request.new("#{BTCE_CONFIG['public_url']}/#{pair.join('_')}/#{type}")
        hydra.queue(requests.last)
      end
      hydra.run
      responses = requests.
        map(&:response).
        map(&:response_body).
        map{ |body| JSON.parse(body)}
      Hash[pairs.map{|p| p.join('_')}.zip(responses)]
    end

    def priv_api_request(type)
      requests  = []
      hydra = Typhoeus::Hydra.new
      requests << Typhoeus::Request.new("#{BTCE_CONFIG['private_url']}/#{pair.join('_')}/#{type}") 
    end

    def buy(pair, amount, rate)
      response = trade({type: BUY, pair: pair, amount: amount, rate: rate}) 
    end

    def sell(pair, amount, rate)
      response = trade({type: SELL, pair: pair, amount: amount, rate: rate})    
    end

    def trade(options)
      puts options.inspect
      uri = URI(BTCE_CONFIG['private_url'])
      req = Net::HTTP::Post.new uri
      @nonce = @redis.get("btce_nonce").to_i
      @redis.set("btce_nonce", (@nonce + 1).to_i)
      
      req.set_form_data(options.merge :method => "Trade", :nonce => @nonce)

      sign = OpenSSL::HMAC::hexdigest('sha512', BTCE_CONFIG['trade_secret'], req.body) 
  
      req["Key"] = BTCE_CONFIG['trade_key']
      req["Sign"] = sign
      req["User-Agent"] = "Chickun 0.1"

      res = Net::HTTP.start(uri.hostname, uri.port, :use_ssl => true) do |http|
        http.request(req)
      end
  
      res = JSON.parse(res.body, symbolize_names: true)

      if res[:success].to_i == 1
        received  = res[:return][:received].to_f
        remaining = res[:return][:remains].to_f
        if remaining == 0
          status = FILLED
        elsif remaining > 0 && remaining < received
          status = PARTIALLY_FILLED
        else
          status = PENDING
        end
        puts "#{options[:type]} #{options[:pair]} #{status}: #{received}/#{options[:amount]}"
      else
        puts "ERROR: #{res.inspect}"
      end
    end
   
    def bid_ask(pairs)
      res = pub_api_request('depth', pairs)
      prices = {}
      res.each do |key, data|
        prices[key.to_sym] = { 
          bid: { price: data["bids"].first[0].to_f.round(8), amount: data["bids"].first[1].to_f.round(8) },
          ask: { price: data["asks"].first[0].to_f.round(8), amount: data["asks"].first[1].to_f.round(8) }
        }
      end
      prices
    end
    
    def smallest_amount_available_in_btc(trade_direction)
      prices = bid_ask([['btc','usd'],['ltc','btc'],['ltc','usd']])
      if trade_direction == 'forward'
        smallest = [
          prices[:btc_usd][:ask][:amount],
          (prices[:ltc_btc][:ask][:amount] * prices[:ltc_btc][:ask][:price]).round(8),
          (prices[:ltc_usd][:bid][:amount] * prices[:ltc_usd][:ask][:price] * prices[:btc_usd][:ask][:price]).round(8)
        ].min
      else
        smallest = [
          prices[:ltc_usd][:ask][:amount],
          (prices[:ltc_btc][:bid][:amount] * prices[:ltc_btc][:bid][:price]).round(8), 
          (prices[:ltc_usd][:bid][:amount] * prices[:ltc_usd][:bid][:price] * prices[:btc_usd][:ask][:price]).round(8) 
        ].min
      end 
      smallest
    end
 
    def account_info
      uri = URI(BTCE_CONFIG['private_url'])
      req = Net::HTTP::Post.new uri
      @nonce = @redis.get("btce_nonce").to_i
      @redis.set("btce_nonce", (@nonce + 1).to_i)
      req.set_form_data({ method: 'getInfo', nonce: @nonce})
      sign = OpenSSL::HMAC::hexdigest('sha512', BTCE_CONFIG['info_secret'], req.body) 
      
      req["Key"] = BTCE_CONFIG['info_key']
      req["Sign"] = sign
      req["User-Agent"] = "Chickun 0.1"

      #puts options.inspect
      res = Net::HTTP.start(uri.hostname, uri.port, :use_ssl => true) do |http|
        http.request(req)
      end
      res.body
    end

    def open_orders
      uri = URI(BTCE_CONFIG['private_url'])
      req = Net::HTTP::Post.new uri
      @nonce = Time.now.to_i
      req.set_form_data({ method: 'ActiveOrders', nonce: @nonce})
      sign = OpenSSL::HMAC::hexdigest('sha512', BTCE_CONFIG['orders_secret'], req.body) 
      
      req["Key"] = BTCE_CONFIG['orders_key']
      req["Sign"] = sign
      req["User-Agent"] = "Chickun 0.1"

      #puts options.inspect
      res = Net::HTTP.start(uri.hostname, uri.port, :use_ssl => true) do |http|
        http.request(req)
      end
      puts res.body
      res.body
    end

    def ticker(*pairs)
      pub_api_request(:ticker, *pairs)
    end

    def trades(*pairs)
      pub_api_request(:trades, *pairs)
    end

    def depth(*pairs)
      pub_api_request(:depth, *pairs)
    end
  end
end
