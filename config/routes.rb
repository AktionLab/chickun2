Chickun2::Application.routes.draw do
  root to: 'pages#home'

  get '/info',        to: 'info#index'
  get '/info/ticker/:pair', to: 'info#ticker'
  get '/:id',         to: 'pages#show', as: :pages
end
