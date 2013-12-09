require 'thread'

class Depth
  def initialize(console, client, pair, x, y, rows, opts={})
    @console = console
    @client  = client
    @pair    = pair
    @x       = x
    @y       = y
    @rows    = rows - 2
    @depth   = nil
    @data_lock = Mutex.new
    @opts    = opts
    @opts[:filter_depth] ||= 0
    @opts[:round_depth_price] = 2
    @opts[:round_depth_vol] = 0
  end

  def draw
    @data_lock.synchronize do
      return if @depth.nil?

      @rows.times do |n|
        @console.position_cursor(@x, @y + n)
        unless @depth.asks[n].nil?
          @console.set_style("32m")
          render_price @depth.asks[n][0]
          render_volume @depth.asks[n][1]
        end
        unless @depth.bids[n].nil?
          @console.set_style("31m")
          @console.position_cursor(@x + 30, @y + n)
          render_price @depth.bids[n][0]
          render_volume @depth.bids[n][1]
        end
      end

      @console.set_style("32m")
      @console.position_cursor(@x, @rows + 2)
      render_price @depth.asks.weighted_avg
      render_volume @depth.asks.sum_volume 

      @console.set_style("31m")
      @console.position_cursor(@x + 30, @rows + 2)
      render_price @depth.bids.weighted_avg
      render_volume @depth.bids.sum_volume
    end
  end

  def render_price(price)
    major = price.to_i.to_s.length
    padding = major + @opts[:round_depth_price] + 1
    @console.p(("%#{padding}.#{@opts[:round_depth_price]}f" % price))
  end

  def render_volume(volume)
    width = @opts[:round_depth_vol] + 6
    @console.p("%#{width}.#{@opts[:round_depth_vol]}f" % volume.round(@opts[:round_depth_vol]))
  end

  def run
    Thread.new do
      while true
        depth = @client.pair_depth(@pair)
        @data_lock.synchronize { @depth = depth }
      end
    end
  end
end
