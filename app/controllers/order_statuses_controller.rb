class OrderStatusesController < ApplicationController
  layout "modal", only: %i[ edit update ]

  before_action :set_order

  def edit
  end

  def update
    @order = Orders::ChangeStatus.call(order: @order, status: params[:status], user: Current.user, comment: params[:comment])

    if @order.errors.empty?
      redirect_to @order, notice: "Статус оновлено."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private
    def set_order
      @order = Order.find(params[:order_id])
    end
end
