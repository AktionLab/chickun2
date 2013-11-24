class TradesController < ApplicationController
  respond_to :json

  def last
    render json: Trade.where(currency_pair_id: CurrencyPair.where(key: params[:pair]).first.id).last
  end
end
