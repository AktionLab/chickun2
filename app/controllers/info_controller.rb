class InfoController < ApplicationController
  respond_to :json 
 
  def initialize
    @method = 'getInfo'
    @private_client = Client::Btce.new(BTCE_CONFIG['private_url'])
    @public_client = Client::Btce.new(BTCE_CONFIG['public_url'])
  end
 
  def index
    render json: @private_client.account_info
  end

  def ticker
    render json: @public_client.pair_ticker(params[:pair])
  end
end
