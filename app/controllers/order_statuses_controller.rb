class OrderStatusesController < ApplicationController
  layout "modal", only: %i[ edit update ]

  before_action :set_order

  def edit
    @mechanics = User.assignable_as_mechanic.active.order(:name)
  end

  def update
    @order = Orders::ChangeStatus.call(order: @order, status: params[:status], user: Current.user,
                                      comment: params[:comment], mechanic_id: params[:mechanic_id])

    if @order.errors.empty?
      respond_to do |format|
        format.turbo_stream { flash.now[:notice] = "Статус оновлено."; render "orders/refresh" }
        format.html { redirect_to @order, notice: "Статус оновлено." }
      end
    else
      @mechanics = User.assignable_as_mechanic.active.order(:name)
      render :edit, status: :unprocessable_entity
    end
  end

  private
    def set_order
      @order = Order.find(params[:order_id])
    end
end
