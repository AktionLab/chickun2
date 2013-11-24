Exchange.delete_all
CurrencyPair.delete_all
Trade.delete_all

[
  { name: 'BTC-e', key: 'btce', website: 'https://btc-e.com' }
].each { |e| Exchange.create! e }

[
  { exchange: Exchange.first, name: 'BTC/USD', key: 'btc_usd' }, 
  { exchange: Exchange.first, name: 'LTC/BTC', key: 'ltc_btc' },
  { exchange: Exchange.first, name: 'LTC/USD', key: 'ltc_usd' }, 
  { exchange: Exchange.first, name: 'NMC/BTC', key: 'nmc_btc' },
  { exchange: Exchange.first, name: 'NMC/USD', key: 'nmc_usd' }, 
  { exchange: Exchange.first, name: 'NVC/USD', key: 'nvc_usd' }, 
  { exchange: Exchange.first, name: 'NVC/BTC', key: 'nvc_btc' }, 
  { exchange: Exchange.first, name: 'TRC/BTC', key: 'trc_btc' }, 
  { exchange: Exchange.first, name: 'PPC/BTC', key: 'ppc_btc' }, 
  { exchange: Exchange.first, name: 'FTC/BTC', key: 'ftc_btc' },	 
  { exchange: Exchange.first, name: 'XPM/BTC', key: 'xpm_btc' } 
].each { |cp| CurrencyPair.create! cp }
