require 'thor'
require 'client/btce'
require 'active_support/inflector'
require 'bigdecimal'
require 'trades'
require 'depth'

module Chickun
  class Cli < Thor
    desc "buy EXCHANGE PAIR AMOUNT RATE", "buy an amount of currency at the given rate"
    def buy(exchange, pair, amount, rate)
    end

    desc "sell EXCHANGE PAIR AMOUNT RATE", "sell an amount of currency at the given rate"
    def sell(exchange, pair, amount, rate)
    end

    desc "trades EXCHANGE PAIR", "display trade history"
    def trades(exchange, pair)
      console = Console.new
      client = Client::const_get(exchange.classify).new
      trap('INT') { console.reset_style; exit }

      trades = Trades.new(console, client, pair, 1, 1, console.rows - 1)
      trades.run

      console.clear
      while true
        console.clear
        console.position_cursor(1,1)
        trades.draw
        sleep 1
      end
    end

    desc "depth EXCHANGE PAIR", "display order depth"
    option :filter_depth
    def depth(exchange, pair)
      opts = options.dup
      console = Console.new
      client  = Client::const_get(exchange.classify).new
      trap('INT') { console.reset_style; exit }

      depth = Depth.new(console, client, pair, 1, 1, console.rows - 1, opts)
      depth.run

      while true
        console.clear
        depth.draw
        sleep 1
      end
    end

    desc "console EXCHANGE PAIR", "trading console"
    option :filter_depth
    def console(exchange, pair)
      opts = options.dup
      console = Console.new
      client  = Client::const_get(exchange.classify).new
      trap('INT') do
        console.reset_style
        console.position_cursor(1,console.rows)
        exit
      end

      depth = Depth.new(console, client, pair, 40, 1, console.rows - 1, opts)
      trades = Trades.new(console, client, pair, 1, 1, console.rows - 1)
      depth.run
      trades.run

      console.clear
      while true
        console.clear
        trades.draw
        depth.draw
        sleep 0.5
      end
    end

  private

    def compress_trades(trades)
      trades.each {|trade| trade[:amount] = BigDecimal.new(trade[:amount].to_s)}

      compressed_trades = [trades.shift]

      trades.each do |trade|
        if trade[:trade_type] == compressed_trades.last[:trade_type] && trade[:price] == compressed_trades.last[:price]
          compressed_trades.last[:amount] += trade[:amount]
        else
          compressed_trades << trade
        end
      end
      compressed_trades
    end
  end
end

class Console
  attr_reader :rows, :cols

  def initialize
    @rows = `tput lines`.to_i
    @cols = `tput cols`.to_i
    @styles = []
  end

  def reset_style
    print "\e[0m"
  end

  def reset_position
    print "\e[H"
  end

  def set_style(*styles)
    @styles = styles
  end

  def clear
    print "\e[2J"
  end

  def position_cursor(x,y)
    y = @rows if y == :bottom
    print "\e[#{y};#{x}H"
  end

  def p(text)
    print "#{@styles.map{|s| "\e[#{s}"}.join('')}#{text}"
  end
end
