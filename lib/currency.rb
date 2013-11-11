class Currency
  cattr_accessor :currencies, :pairs
  self.currencies = %w(cnc ftc ppc trc nvc nmc ltc btc eur usd rur).map(&:to_sym)
  self.pairs = [ %w(btc usd), %w(btc rur), %w(btc eur), %w(ltc btc), %w(ltc usd), %w(ltc rur), %w(nmc btc),
                 %w(usd rur), %w(nvc btc), %w(trc btc), %w(ppc btc), %w(ftc btc), %w(cnc btc) ]

  attr_reader :symbol, :priority

  def self.method_missing(method, *args)
    if currencies.include?(method.to_sym)
      Currency.new(method)
    else
      super
    end
  end

  def initialize(symbol)
    @symbol = symbol
    @priority = currencies.index symbol
  end

  def currencies
    self.class.currencies
  end

  def to_s
    symbol.to_s
  end

  def trade_for(currency)
    [self,currency].sort{|a,b| a.priority <=> b.priority}.join('_')
  end
end
