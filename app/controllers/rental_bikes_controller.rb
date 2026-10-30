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
    # Photos are attached, never assigned: has_many_attached's `photos =`
    # replaces the whole set, so every new batch from the fleet's "+" used to
    # wipe the earlier ones.
    attributes = rental_bike_params
    new_photos = Array(attributes.delete(:photos)).compact_blank
    @rental_bike.assign_attributes(attributes)
    @rental_bike.photos.attach(new_photos) if new_photos.any?

    if @rental_bike.save
      redirect_to rentals_path, notice: "Велосипед оновлено."
    else
      redirect_to rentals_path, alert: @rental_bike.errors.full_messages.to_sentence
    end
  end

  # Photos are added one batch at a time from the fleet list, and removed one
  # at a time — neither needs the whole record's form.
  def destroy_photo
    bike = RentalBike.find(params[:id])
    bike.photos.find(params[:photo_id]).purge

    redirect_to rentals_path, notice: "Фото видалено."
  end

  private
    def rental_bike_params
      params.expect(rental_bike: [ :name, :size, :daily_rate, :note, :active, { photos: [] } ])
    end
end
