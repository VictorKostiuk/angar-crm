# «Клієнт приїхав»: a booked order becomes «Нове». A one-click shortcut for the
# same transition the status modal allows — Orders::ChangeStatus resets
# accepted_at / accepted_by to the moment and the person at the counter.
class OrderArrivalsController < ApplicationController
  def update
    order = Order.find(params[:order_id])

    unless order.booked?
      redirect_to order, alert: "Це замовлення вже не в статусі «Запис»."
      return
    end

    order = Orders::ChangeStatus.call(order: order, status: :intake, user: Current.user, comment: "Клієнт приїхав за записом")

    if order.errors.empty?
      redirect_to order, notice: "Велосипед прийнято."
    else
      redirect_to order, alert: order.errors.full_messages.to_sentence
    end
  end
end
