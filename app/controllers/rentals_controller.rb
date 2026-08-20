class RentalsController < ApplicationController
  layout "modal", only: %i[ new create ]

  def index
    @period = PeriodFilter.new(**period_params)
    @bikes = RentalBike.active.ordered
    @out_ids = RentalBike.out_ids(@bikes)
    @current_by_bike = Rental.outstanding.includes(:client).index_by(&:rental_bike_id)
    @rentals = Rental.in_range(@period.range).includes(:rental_bike, :client, :issued_by).ordered
    @total = @rentals.sum(&:amount)
    @rental_bike = RentalBike.new
  end

  def new
    @rental = Rental.new(rented_from: Date.current, rented_to: Date.current + 1)
    load_form_data
  end

  def create
    @rental = Rental.new(rental_params)
    @rental.issued_by = Current.user

    if @rental.save
      redirect_to rentals_path, notice: "Велосипед видано в прокат."
    else
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
      @free_bikes = RentalBike.active.ordered.reject(&:out?)
      @clients = Client.order(:name)
    end

    def rental_params
      params.expect(rental: %i[ rental_bike_id client_id renter_name renter_phone rented_from rented_to daily_rate note ])
    end
end
