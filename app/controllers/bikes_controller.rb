class BikesController < ApplicationController
  layout "modal", only: %i[ new create ]

  before_action :set_client, only: %i[ new create ]

  def index
    load_index_data
  end

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

  def update
    @bike = Bike.find(params[:id])

    if @bike.update(bike_params)
      respond_to do |format|
        format.turbo_stream { load_index_data; render :refresh }
        format.html { redirect_to bikes_path(q: params[:q]), notice: "Велосипед оновлено." }
      end
    else
      respond_to do |format|
        format.turbo_stream { render :form_error, status: :unprocessable_entity }
        format.html { load_index_data; render :index, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    Bike.find(params[:id]).update!(active: false)

    respond_to do |format|
      format.turbo_stream do
        load_index_data
        render turbo_stream: turbo_stream.update("bikes_rows", partial: "rows", locals: { bikes: @bikes })
      end
      format.html { redirect_to bikes_path(q: params[:q]), notice: "Велосипед архівовано." }
    end
  end

  private
    def set_client
      @client = Client.find(params[:client_id])
    end

    def bike_params
      params.expect(bike: %i[ name brand model color size notes ])
    end

    def load_index_data
      @bikes = Bike.active.search(params[:q]).ordered.includes(:client)
      @bike = params[:edit].present? ? Bike.find(params[:edit]) : nil
    end
end
