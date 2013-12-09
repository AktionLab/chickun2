require 'thread'

class Trades
  def initialize(console, client, pair, x, y, rows)
    @console = console
    @client  = client
    @pair    = pair
    @x       = x
    @y       = y
    @rows    = rows
    @trades  = []
    @trades_lock = Mutex.new
  end

  def draw
    trades = []
    @trades_lock.synchronize { trades = @trades.dup }
    trades.each_with_index do |trade,n|
      time = Time.at(trade[:date]).strftime("%H:%M:%S")
      @console.set_style(trade[:trade_type] == 'bid' ? "32m" : "31m")
      @console.position_cursor(@x, @y + n)
      @console.p("#{time} | #{trade[:price].to_s.ljust(8, ' ')} | #{trade[:amount].to_f.to_s.ljust(10, ' ')}")
    end
  end

  def run
    Thread.new do
      while true
        trades = trade_history.first(@rows)
        @trades_lock.synchronize { @trades = trades }
      end
    end
  end

private

  def trade_history
    trades = @client.pair_trade_history(@pair)
    trades.each {|trade| trade[:amount] = BigDecimal.new(trade[:amount].to_s)}
    init   = [trades.shift]
    trades.inject(init) do |ts,t|
      if ts.last[:trade_type] == t[:trade_type] && ts.last[:price] == t[:price]
        ts.last[:amount] += t[:amount]
      else
        ts << t
      end
      ts
    end
  end
end
