class WorkshopController < ApplicationController
  def index
    # The bike's photos and its other visits' photos feed the card's thumbnail
    # when this order has none of its own (D68).
    orders = Order.open_orders.includes(:client, :mechanic, :maintenance_type,
                                        bike: [ { photos_attachments: :blob }, { orders: { photos_attachments: :blob } } ])
                  .with_attached_photos.order(accepted_at: :asc)
    grouped = orders.group_by(&:status)
    # Bookings read in appointment order — the next client to arrive first.
    grouped["booked"] = grouped["booked"]&.sort_by(&:scheduled_at)
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
