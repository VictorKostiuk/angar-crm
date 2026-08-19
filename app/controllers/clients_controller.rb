class ClientsController < ApplicationController
  layout "modal", only: %i[ new create edit update ]

  before_action :set_client, only: %i[ show edit update ]

  def index
    scope = Client.search(params[:q])
    @total_count = scope.count
    @clients = scope.order(:name).paginate(page: params[:page])
  end

  def show
    @bikes = @client.bikes.active.order(:name)
    @orders = @client.orders.order(accepted_at: :desc)
  end

  def new
    @client = Client.new
  end

  def create
    @client = Client.new(client_params)

    if @client.save
      redirect_to @client, notice: "Клієнта додано."
    else
      render "shared/modal_form_error", locals: { form_template: "clients/new" }, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @client.update(client_params)
      redirect_to @client, notice: "Клієнта оновлено."
    else
      render "shared/modal_form_error", locals: { form_template: "clients/edit" }, status: :unprocessable_entity
    end
  end

  # Reused by the order intake screen (P3) to look up a client as-you-type.
  def search
    @clients = Client.search(params[:q]).order(:name).limit(10)
    render layout: false
  end

  private
    def set_client
      @client = Client.find(params[:id])
    end

    def client_params
      params.expect(client: %i[ name phone email city notes ])
    end
end
