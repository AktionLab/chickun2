Chickun2::Application.routes.draw do
  root to: 'pages#home'

  get '/info',              to: 'info#index'
  get '/info/open_orders',   to: 'info#open_orders'
  get '/info/ticker/:pair', to: 'info#ticker'
  get '/trades/:pair',      to: 'trades#last' 
  get '/:id',               to: 'pages#show', as: :pages
end
