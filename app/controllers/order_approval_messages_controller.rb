# The «Очікує погодження» message — recommended works and parts with an
# estimated total — that a mechanic copies and sends to the client. Read-only,
# exactly like OrderReadyMessagesController: the action buttons decide when it
# is offered (waiting_approval), and reaching the URL by hand only renders text.
class OrderApprovalMessagesController < ApplicationController
  layout "modal", only: :show

  def show
    @order = Order.find(params[:order_id])
  end
end
