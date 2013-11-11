class PagesController < ApplicationController
  def show
    begin
      render params[:id]
    rescue ActionView::MissingTemplate
      raise ActionController::RoutingError.new("No route matches [GET] \"/#{params[:id]}\"")
    end
  end
end
