class OrderPaymentsController < ApplicationController
  layout "modal", only: %i[ edit update ]

  before_action :set_order

  def edit
  end

  def update
    if @order.cancelled?
      @order.errors.add(:base, "Скасоване замовлення не можна оплатити")
      render :edit, status: :unprocessable_entity
      return
    end

    unless params[:payment_method].blank? || Order.payment_methods.key?(params[:payment_method])
      @order.errors.add(:payment_method, "недійсне значення")
      render :edit, status: :unprocessable_entity
      return
    end

    @order.assign_attributes(
      payment_method: params[:payment_method],
      receipt_number: params[:receipt_number],
      payment_status: :paid,
      paid_at: @order.paid_at || Time.current
    )

    if @order.save
      redirect_to @order, notice: "Оплату зафіксовано."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private
    def set_order
      @order = Order.find(params[:order_id])
    end
end
