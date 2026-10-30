# Photos of a client's bike, added a batch at a time from the bike page and
# removed one at a time — the same shape as OrderPhotosController, and its own
# controller for the same reason: has_many_attached's `photos =` setter
# replaces the whole set, so routing this through BikesController#update would
# drop every earlier photo on the next unrelated edit.
class BikePhotosController < ApplicationController
  before_action :set_bike

  def create
    files = Array(params[:photos]).reject(&:blank?)

    if files.any? { |file| !file.content_type.to_s.start_with?("image/") }
      redirect_to @bike, alert: "Фото має бути зображенням."
      return
    end

    @bike.photos.attach(files) if files.any?
    redirect_to @bike, notice: "Фото додано."
  end

  def destroy
    @bike.photos.find(params[:id]).purge
    redirect_to @bike, notice: "Фото видалено."
  end

  private
    def set_bike
      @bike = Bike.find(params[:bike_id])
    end
end
