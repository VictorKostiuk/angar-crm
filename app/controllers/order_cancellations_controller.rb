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

    was_booked = @order.booked?

    if @order.update(status: :cancelled, cancelled_at: Time.current, cancel_reason: params[:reason])
      notice = was_booked ? "Запис скасовано." : "Замовлення скасовано."
      alert = nil

      # A booking the client may still be planning around: tell them, through
      # the bot, if they use it and the box was left ticked (D64). The
      # cancellation stands either way — a failed message only gets reported.
      if was_booked && params[:notify_telegram] == "1"
        result = Telegram::Notifier.new.booking_cancelled(@order)
        if result.sent?
          notice += " Клієнту надіслано повідомлення в Telegram."
        else
          alert = "Повідомлення в Telegram не надіслано: #{result.error}. Зв'яжіться з клієнтом іншим способом."
        end
      end

      respond_to do |format|
        format.turbo_stream { flash.now[:notice] = notice; flash.now[:alert] = alert; render "orders/refresh" }
        format.html { redirect_to @order, notice: notice, alert: alert }
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
