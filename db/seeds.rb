Exchange.delete_all
CurrencyPair.delete_all
Trade.delete_all

[
  { name: 'BTC-e', key: 'btce', website: 'https://btc-e.com' }
].each { |e| Exchange.create! e }

[
  { exchange: Exchange.first, name: 'BTC/USD', key: 'btc_usd' }, 
  { exchange: Exchange.first, name: 'LTC/BTC', key: 'ltc_btc' },
  { exchange: Exchange.first, name: 'LTC/USD', key: 'ltc_usd' } 
].each { |cp| CurrencyPair.create! cp }
