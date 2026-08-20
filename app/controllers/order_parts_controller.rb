class OrderPartsController < ApplicationController
  layout "modal", only: %i[ new ]

  before_action :set_order
  before_action :require_editable_order, only: %i[ new create update destroy ]

  def new
    @categories = Category.part.active.ordered
    @order_part = @order.order_parts.new
  end

  def create
    @order_part = @order.order_parts.new(order_part_params)

    if @order_part.save
      respond_to do |format|
        format.turbo_stream { render "order_parts/refresh" }
        format.html { redirect_to @order, notice: "Запчастину додано." }
      end
    else
      respond_to do |format|
        format.turbo_stream { render "order_parts/custom_form_error", status: :unprocessable_entity }
        format.html { render :new, status: :unprocessable_entity }
      end
    end
  end

  def update
    order_part = @order.order_parts.find(params[:id])
    order_part.update(order_part_params)

    respond_to do |format|
      format.turbo_stream { render "order_parts/refresh" }
      format.html { redirect_to @order }
    end
  end

  def destroy
    @order.order_parts.find(params[:id]).destroy

    respond_to do |format|
      format.turbo_stream { render "order_parts/refresh" }
      format.html { redirect_to @order }
    end
  end

  private
    def require_editable_order
      return if @order.editable?

      redirect_to @order, alert: "Замовлення закрито або скасовано — редагування недоступне."
    end
    def set_order
      @order = Order.find(params[:order_id])
    end

    def order_part_params
      params.expect(order_part: %i[ part_id name quantity price ])
    end
end
