# The "готове до видачі" message a mechanic copies and sends to the client.
# Showing it writes nothing, so there is no editable?/status guard there — the
# action buttons decide when the message is worth offering (waiting_pickup),
# and reaching this URL by hand only ever renders text.
#
# create sends that same text through the Telegram bot (D64). It does reach
# the client, so unlike show it insists on the order actually being ready.
class OrderReadyMessagesController < ApplicationController
  layout "modal", only: %i[ show create ]

  before_action :set_order

  def show
  end

  def create
    unless @order.waiting_pickup?
      @telegram_error = "Повідомлення про готовність надсилається лише у статусі «#{t("statuses.order.waiting_pickup")}»."
      return render :show, status: :unprocessable_entity
    end

    result = Telegram::Notifier.new.ready(@order, helpers.order_ready_message(@order))

    if result.sent?
      @order.touch(:ready_notified_at)
      respond_to do |format|
        format.turbo_stream { flash.now[:notice] = "Повідомлення надіслано клієнту в Telegram."; render "orders/refresh" }
        format.html { redirect_to @order, notice: "Повідомлення надіслано клієнту в Telegram." }
      end
    else
      @telegram_error = "Не надіслано: #{result.error}. Скопіюйте текст і надішліть вручну."
      render :show, status: :unprocessable_entity
    end
  end

  private
    def set_order
      @order = Order.find(params[:order_id])
    end
end
