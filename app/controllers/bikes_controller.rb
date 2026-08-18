class BikesController < ApplicationController
  layout "modal"

  before_action :set_client

  def new
    @bike = @client.bikes.new
  end

  def create
    @bike = @client.bikes.new(bike_params)

    if @bike.save
      redirect_to @client, notice: "Велосипед додано."
    else
      render :new, status: :unprocessable_entity
    end
  end

  private
    def set_client
      @client = Client.find(params[:client_id])
    end

    def bike_params
      params.expect(bike: %i[ name brand model color size notes ])
    end
end
