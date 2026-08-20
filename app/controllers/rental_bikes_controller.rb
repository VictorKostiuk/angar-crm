class RentalBikesController < ApplicationController
  require_role :admin, :owner

  def create
    @rental_bike = RentalBike.new(rental_bike_params)

    if @rental_bike.save
      redirect_to rentals_path, notice: "Велосипед додано до прокату."
    else
      redirect_to rentals_path, alert: @rental_bike.errors.full_messages.to_sentence
    end
  end

  def update
    @rental_bike = RentalBike.find(params[:id])
    @rental_bike.update(rental_bike_params)

    redirect_to rentals_path, notice: "Велосипед оновлено."
  end

  private
    def rental_bike_params
      params.expect(rental_bike: %i[ name size daily_rate note active ])
    end
end
