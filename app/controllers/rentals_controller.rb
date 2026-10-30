class RentalsController < ApplicationController
  layout "modal", only: %i[ new create ]

  def index
    @period = PeriodFilter.new(**period_params)
    @bikes = RentalBike.active.ordered.with_attached_photos
    @out_ids = RentalBike.out_ids(@bikes)
    @current_by_bike = Rental.outstanding.includes(client: { documents_attachments: :blob })
                             .with_attached_documents.index_by(&:rental_bike_id)
    @rentals = Rental.in_range(@period.range)
                     .includes(:issued_by, client: { documents_attachments: :blob }, rental_bike: { photos_attachments: :blob })
                     .with_attached_documents.ordered
    @total = @rentals.sum(&:amount)
    @rental_bike = RentalBike.new
  end

  def new
    @rental = Rental.new(rented_from: Date.current, rented_to: Date.current + 1)
    @bike_ids = Array(params[:rental_bike_ids]).map(&:to_s)
    load_form_data
  end

  # Several bikes to one person in one go (D67) — see Rentals::Issue. A single
  # rental_bike_id is still accepted, as before.
  def create
    attributes = rental_params.except(:rental_bike_id, :rental_bike_ids, :documents)
    @bike_ids = Array(rental_params[:rental_bike_ids].presence || rental_params[:rental_bike_id]).compact_blank.map(&:to_s)
    files = Array(rental_params[:documents]).compact_blank
    issue = Rentals::Issue.call(attributes: attributes, bike_ids: @bike_ids, documents: files, issued_by: Current.user)

    if issue.success?
      count = issue.rentals.size
      redirect_to rentals_path, notice: count == 1 ? "Велосипед видано в прокат." : "Видано в прокат: #{count} #{bikes_word(count)}."
    else
      @rental = Rental.new(attributes)
      issue.errors.each { |message| @rental.errors.add(:base, message) }
      @documents_lost = files.any?
      load_form_data
      render "shared/modal_form_error", locals: { form_template: "rentals/new" }, status: :unprocessable_entity
    end
  end

  # Returning is a state change on an existing hire, not a new record — the
  # money was recognised when the bike went out.
  def update
    rental = Rental.find(params[:id])
    rental.update(returned_at: Time.current)

    redirect_to rentals_path, notice: "Велосипед повернуто."
  end

  private
    def period_params
      params.permit(:period, :from, :to).to_h.symbolize_keys
    end

    def load_form_data
      @free_bikes = RentalBike.active.ordered.with_attached_photos.reject(&:out?)
      @clients = Client.order(:name)
    end

    def rental_params
      params.expect(rental: [ :rental_bike_id, :client_id, :renter_name, :renter_phone,
                              :rented_from, :rented_to, :daily_rate, :note, { rental_bike_ids: [], documents: [] } ])
    end

    def bikes_word(count)
      case count % 100
      when 11..14 then "велосипедів"
      else { 1 => "велосипед", 2 => "велосипеди", 3 => "велосипеди", 4 => "велосипеди" }.fetch(count % 10, "велосипедів")
      end
    end
end
