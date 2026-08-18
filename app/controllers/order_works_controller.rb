class OrderWorksController < ApplicationController
  layout "modal", only: %i[ new ]

  before_action :set_order

  def new
    @order_work = @order.order_works.new
  end

  def create
    @order_work = @order.order_works.new(order_work_params)

    if @order_work.save
      respond_to do |format|
        format.turbo_stream { render "order_works/refresh" }
        format.html { redirect_to @order, notice: "Роботу додано." }
      end
    else
      respond_to do |format|
        format.turbo_stream { render "order_works/custom_form_error", status: :unprocessable_entity }
        format.html { render :new, status: :unprocessable_entity }
      end
    end
  end

  def update
    order_work = @order.order_works.find(params[:id])
    order_work.update(order_work_params)

    respond_to do |format|
      format.turbo_stream { render "order_works/refresh" }
      format.html { redirect_to @order }
    end
  end

  def destroy
    @order.order_works.find(params[:id]).destroy

    respond_to do |format|
      format.turbo_stream { render "order_works/refresh" }
      format.html { redirect_to @order }
    end
  end

  private
    def set_order
      @order = Order.find(params[:order_id])
    end

    def order_work_params
      params.expect(order_work: %i[ service_id name quantity price ])
    end
end
