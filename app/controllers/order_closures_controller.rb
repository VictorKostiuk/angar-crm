class OrderClosuresController < ApplicationController
  layout "modal", only: %i[ edit update ]

  before_action :set_order

  def edit
  end

  def update
    @order = Orders::Close.call(order: @order)

    if @order.closed?
      redirect_to @order, notice: "Замовлення закрито."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private
    def set_order
      @order = Order.find(params[:order_id])
    end
end
