class OrderClosuresController < ApplicationController
  layout "modal", only: %i[ edit update ]

  before_action :set_order

  def edit
  end

  def update
    @order = Orders::Close.call(order: @order)

    if @order.closed?
      respond_to do |format|
        format.turbo_stream { flash.now[:notice] = "Замовлення закрито."; render "orders/refresh" }
        format.html { redirect_to @order, notice: "Замовлення закрито." }
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
