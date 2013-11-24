class InfoController < ApplicationController
  respond_to :json 
 
  def initialize
    @client = Client::Btce.new(BTCE_CONFIG['public_url'], BTCE_CONFIG['private_url'])
  end
 
  def index
    render json: @client.account_info
  end

  def ticker
    render json: @client.pair_ticker(params[:pair])
  end

  def open_orders
    render json: @client.open_orders
  end
end
