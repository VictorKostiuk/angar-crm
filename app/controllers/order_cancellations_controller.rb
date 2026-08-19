class OrderCancellationsController < ApplicationController
  layout "modal", only: %i[ edit update ]

  before_action :set_order

  def edit
  end

  def update
    unless @order.open_status?
      @order.errors.add(:base, "Замовлення вже закрито або скасовано")
      render :edit, status: :unprocessable_entity
      return
    end

    if @order.update(status: :cancelled, cancelled_at: Time.current, cancel_reason: params[:reason])
      respond_to do |format|
        format.turbo_stream { flash.now[:notice] = "Замовлення скасовано."; render "orders/refresh" }
        format.html { redirect_to @order, notice: "Замовлення скасовано." }
      end
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private
    def set_order
      @order = Order.find(params[:order_id])
    end
end
