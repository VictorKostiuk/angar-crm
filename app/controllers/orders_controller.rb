class OrdersController < ApplicationController
  before_action :set_order, only: %i[ show update ]

  def new
    @order = Order.new
    @client = params[:client_id].present? ? Client.find(params[:client_id]) : nil
    @mechanics = User.active.order(:name)
  end

  def create
    accepted_by = params[:accepted_by_id].presence ? User.find(params[:accepted_by_id]) : Current.user

    order = Orders::Create.call(
      accepted_by: accepted_by,
      client_id: params[:client_id],
      client_name: params[:client_name],
      client_phone: params[:client_phone],
      bike_id: params[:bike_id],
      bike_name: params[:bike_name],
      problem: params[:problem],
      comment: params[:comment]
    )

    if order.persisted?
      redirect_to order, notice: "Замовлення прийнято."
    else
      @order = order
      @client = order.client&.persisted? ? order.client : nil
      @mechanics = User.active.order(:name)
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @order_works = @order.order_works.order(:position)
    @order_parts = @order.order_parts.order(:position)
    @order_status_changes = @order.order_status_changes.includes(:user)
    @mechanics = User.active.order(:name)
  end

  def update
    if @order.update(order_params)
      redirect_to @order, notice: "Замовлення оновлено."
    else
      @order_works = @order.order_works.order(:position)
      @order_parts = @order.order_parts.order(:position)
      @order_status_changes = @order.order_status_changes.includes(:user)
      @mechanics = User.active.order(:name)
      render :show, status: :unprocessable_entity
    end
  end

  private
    def set_order
      @order = Order.find(params[:id])
    end

    def order_params
      params.expect(order: %i[ mechanic_id expected_ready_on discount ])
    end
end
