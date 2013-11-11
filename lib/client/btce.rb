module Client
  class Btce
    def initialize(url)
      @url = url
    end

    def pair_ticker(pair)
      url = URI.parse("#{@url}/#{pair}/ticker")
      req = Net::HTTP::Get.new(url.path)
      res = Net::HTTP.start(url.host, url.port, use_ssl: true) {|http|
        http.request(req)
      }
      res.body   
    end

    def pub_api_request(type, pairs)
      requests  = []
      hydra = Typhoeus::Hydra.new

      pairs.each do |pair|
        requests << Typhoeus::Request.new("#{@url}/#{pair.join('_')}/#{type}")
        hydra.queue(requests.last)
      end
      hydra.run
      responses = requests.map(&:response).map(&:body).map{|body| JSON.parse(body)[type.to_s]}
      Hash[pairs.map{|p| p.join('_')}.zip(responses)]
    end

    def priv_api_request(type)
      requests  = []
      hydra = Typhoeus::Hydra.new
      requests << Typhoeus::Request.new("#{@url}/#{pair.join('_')}/#{type}") 
    end

    def account_info
      uri = URI(@url)
      req = Net::HTTP::Post.new uri
      @nonce = Time.now.to_i
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
