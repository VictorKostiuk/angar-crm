# The "готове до видачі" message a mechanic copies and sends to the client.
# Read-only: nothing here writes, so there is no editable?/status guard — the
# action buttons decide when the message is worth offering (waiting_pickup),
# and reaching this URL by hand only ever renders text.
class OrderReadyMessagesController < ApplicationController
  layout "modal", only: :show

  def show
    @order = Order.find(params[:order_id])
  end
end
