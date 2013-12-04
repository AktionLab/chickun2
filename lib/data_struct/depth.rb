module DataStruct
  class Depth
    attr_reader :bids, :asks

    def initialize(bids, asks)
      @bids = OrderList.new(bids)
      @asks = OrderList.new(asks)
    end

    def spread
      @asks.first[0] - @bids.first[0]
    end

    def weighted_avg
      volume = @asks.sum_volume + @bids.sum_volume
      ask_weight = @asks.sum_volume / volume
      bid_weight = @bids.sum_volume / volume
      @asks.weighted_avg * ask_weight + @bids.weigted_avg * bid_weight
    end

    class OrderList
      include Enumerable

      def initialize(orders)
        @orders = orders.map{|order| [BigDecimal.new(order[0].to_s), BigDecimal.new(order[1].to_s)]}
      end

      def [](n)
        @orders[n]
      end

      def each(&block)
        @orders.each(&block)
      end

      def sum_volume
        @sum_volume ||= map{|order| order[1]}.reduce(:+)
      end

      def weighted_avg
        @weighted_avg ||= reduce(BigDecimal.new('0')) {|sum,o| sum + (o[0] * (o[1] / sum_volume))}
      end
    end
  end
end
