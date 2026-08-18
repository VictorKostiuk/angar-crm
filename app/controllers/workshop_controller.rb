class WorkshopController < ApplicationController
  def index
    orders = Order.open_orders.includes(:client, :bike, :mechanic).with_attached_photos.order(accepted_at: :asc)
    grouped = orders.group_by(&:status)
    @orders_by_status = Order::OPEN_STATUSES.index_with { |status| grouped[status] || [] }
  end

  # Quick "approve" action for the Очікує погодження section (mockup 01) —
  # reuses Orders::ChangeStatus like the P4.2 modal, but responds with a
  # Turbo Stream that moves the card between sections in place instead of
  # navigating away from the board.
  def approve
    order = Order.find(params[:id])
    @order = Orders::ChangeStatus.call(order: order, status: :in_progress, user: Current.user)

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to root_path }
    end
  end
end
