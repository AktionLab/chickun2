require 'thor'
require 'client/btce'
require 'active_support/inflector'
require 'bigdecimal'

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

      while true
        trades = client.pair_trade_history(pair)

        console.clear
        console.position_cursor(1,1)

        compress_trades(trades).first(console.rows - 1).each do |trade|
          time = Time.at(trade[:date]).strftime("%H:%M:%S")

          console.set_style(trade[:trade_type] == 'bid' ? "32m" : "31m")
          console.p("#{time}  #{trade[:amount].to_f.to_s.rjust(10, ' ')}  #{trade[:price]}\n")
        end
      end
    end

    desc "depth EXCHANGE PAIR", "display order depth"
    def depth(exchange, pair)
      console = Console.new
      client  = Client::const_get(exchange.classify).new
      trap('INT') { console.reset_style; exit }

      while true
        orders = client.pair_depth(pair)

        console.clear
        console.position_cursor(1,1)

        (console.rows - 1).times do |n|
          console.set_style("32m")
          console.p("#{orders[:asks][n][0].to_s.ljust(10, ' ')} #{orders[:asks][n][1]}".ljust(30, ' '))
          console.set_style("31m")
          console.p("#{orders[:bids][n][0].to_s.ljust(10, ' ')} #{orders[:bids][n][1]}\n")
        end
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
