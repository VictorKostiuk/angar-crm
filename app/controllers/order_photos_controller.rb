class OrderPhotosController < ApplicationController
  before_action :set_order

  def create
    files = Array(params[:photos]).reject(&:blank?)

    if files.any? { |file| !file.content_type.to_s.start_with?("image/") }
      redirect_to @order, alert: "Фото має бути зображенням."
      return
    end

    @order.photos.attach(files) if files.any?
    redirect_to @order, notice: "Фото додано."
  end

  def destroy
    @order.photos.find(params[:id]).purge
    redirect_to @order, notice: "Фото видалено."
  end

  private
    def set_order
      @order = Order.find(params[:order_id])
    end
end
