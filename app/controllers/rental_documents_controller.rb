# The renter's ID photos, added one batch at a time from the rentals list and
# removed one at a time — neither needs the whole hire's form, and Rental's own
# PATCH already means "bike returned".
#
# Adding is open to every role because every role issues rentals (D42) and the
# documents are taken at handover. Deleting is admin/owner, matching
# RentalBikesController#destroy_photo — purging someone's ID is not a mechanic's
# call to make from the floor.
class RentalDocumentsController < ApplicationController
  require_role :admin, :owner, only: :destroy

  before_action :set_rental

  def create
    files = Array(params[:documents]).reject(&:blank?)

    if files.any? { |file| !file.content_type.to_s.start_with?("image/") }
      redirect_to rentals_path, alert: "Документ має бути зображенням."
      return
    end

    @rental.documents.attach(files) if files.any?
    redirect_to rentals_path, notice: "Документи додано."
  end

  def destroy
    @rental.documents.find(params[:id]).purge
    redirect_to rentals_path, notice: "Документ видалено."
  end

  private
    def set_rental
      @rental = Rental.find(params[:rental_id])
    end
end
