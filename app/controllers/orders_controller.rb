class OrdersController < ApplicationController
  before_action :set_order, only: %i[ show update ]
  before_action :require_editable_order, only: :update

  # Замовлення lists live orders only; everything settled — closed *and*
  # cancelled — lives in Архів. `status=archive` is a pseudo-status for that
  # pair, deliberately one param rather than a second one bolted alongside, so
  # the nav link, the active check and the dropdown all read the same value.
  # Explicitly filtering by a real status still works and overrides both.
  ARCHIVE_STATUSES = %w[ closed cancelled ].freeze

  def index
    scope = Order.search(params[:q]).includes(:client, :bike, :mechanic)
    if Order.statuses.key?(params[:status])
      scope = scope.where(status: params[:status])
    elsif params[:status] == "archive"
      scope = scope.where(status: ARCHIVE_STATUSES)
    else
      scope = scope.where.not(status: ARCHIVE_STATUSES)
    end
    scope = scope.where(payment_status: params[:payment_status]) if Order.payment_statuses.key?(params[:payment_status])
    scope = scope.where(mechanic_id: params[:mechanic_id]) if params[:mechanic_id].present?
    scope = scope.via_booking if params[:source] == "booking"
    scope = scope.walk_in if params[:source] == "walk_in"

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
    @discounts = discounts_for(@order)
  end

  def update
    if @order.update(order_params)
      redirect_to @order, notice: "Замовлення оновлено."
    else
      @order_works = @order.order_works.order(:position)
      @order_parts = @order.order_parts.order(:position)
      @order_status_changes = @order.order_status_changes.includes(:user)
      @mechanics = User.assignable_as_mechanic.active.order(:name)
      @discounts = discounts_for(@order)
      render :show, status: :unprocessable_entity
    end
  end

  private
    # Archiving a discount must not make the orders that used it read as
    # "Без знижки" — keep the order's own entry in the list even when it is no
    # longer offered for new orders.
    def discounts_for(order)
      discounts = Discount.active.ordered.to_a
      discounts << order.discount_record if order.discount_record && discounts.exclude?(order.discount_record)
      discounts
    end

    def require_editable_order
      return if @order.editable?

      redirect_to @order, alert: "Замовлення закрито або скасовано — редагування недоступне."
    end

    def set_order
      @order = Order.find(params[:id])
    end

    def parse_date(value)
      Date.parse(value) if value.present?
    rescue ArgumentError
      nil
    end

    def order_params
      params.expect(order: %i[ mechanic_id expected_ready_on discount_record_id problem ])
    end
end
