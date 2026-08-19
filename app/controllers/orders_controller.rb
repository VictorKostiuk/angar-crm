class OrdersController < ApplicationController
  before_action :set_order, only: %i[ show update ]

  # Default view excludes closed orders — they live in Архів
  # (orders_path(status: "closed")) since that's already a one-click nav
  # shortcut to them. Explicitly filtering by any status, including
  # "Закрито" via the dropdown or the Архів link, still works.
  def index
    scope = Order.search(params[:q]).includes(:client, :bike, :mechanic)
    if Order.statuses.key?(params[:status])
      scope = scope.where(status: params[:status])
    else
      scope = scope.where.not(status: :closed)
    end
    scope = scope.where(payment_status: params[:payment_status]) if Order.payment_statuses.key?(params[:payment_status])
    scope = scope.where(mechanic_id: params[:mechanic_id]) if params[:mechanic_id].present?

    from = parse_date(params[:from])
    to = parse_date(params[:to])
    scope = scope.where(accepted_at: from.beginning_of_day..to.end_of_day) if from && to

    @total_count = scope.count
    @orders = scope.order(accepted_at: :desc).paginate(page: params[:page])
    @mechanics = User.assignable_as_mechanic.active.order(:name)
  end

  def new
    @order = Order.new
    @client = params[:client_id].present? ? Client.find(params[:client_id]) : nil
    @mechanics = User.assignable_as_mechanic.active.order(:name)
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
      comment: params[:comment],
      photos: params[:photos]
    )

    if order.persisted?
      redirect_to order, notice: "Замовлення прийнято."
    else
      @order = order
      @client = order.client&.persisted? ? order.client : nil
      @mechanics = User.assignable_as_mechanic.active.order(:name)
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @order_works = @order.order_works.order(:position)
    @order_parts = @order.order_parts.order(:position)
    @order_status_changes = @order.order_status_changes.includes(:user)
    @mechanics = User.assignable_as_mechanic.active.order(:name)
    @discounts = Discount.active.ordered
  end

  def update
    if @order.update(order_params)
      redirect_to @order, notice: "Замовлення оновлено."
    else
      @order_works = @order.order_works.order(:position)
      @order_parts = @order.order_parts.order(:position)
      @order_status_changes = @order.order_status_changes.includes(:user)
      @mechanics = User.assignable_as_mechanic.active.order(:name)
      @discounts = Discount.active.ordered
      render :show, status: :unprocessable_entity
    end
  end

  private
    def set_order
      @order = Order.find(params[:id])
    end

    def parse_date(value)
      Date.parse(value) if value.present?
    rescue ArgumentError
      nil
    end

    def order_params
      params.expect(order: %i[ mechanic_id expected_ready_on discount ])
    end
end
