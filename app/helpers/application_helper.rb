module ApplicationHelper
  # 1920.0 -> "1 920 грн"
  def money(amount)
    return "—" if amount.nil?

    grouped = amount.round.to_i.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\1 ').reverse
    "#{grouped} грн"
  end

  # Wraps a page's filter controls and the list they filter, so applying a
  # filter swaps only that region instead of the whole <body> — which is what
  # resets scroll to the top today.
  #
  # target: "_top" is the crux: every row link, detail link and action inside
  # keeps navigating normally, and ONLY the controls that opt in with
  # data-turbo-frame drive the frame. The other way round means hunting down
  # every escape link, and one missed link renders "Content missing".
  #
  # data-turbo-action="advance" keeps the address bar in step, so a filtered
  # view survives a reload and can still be shared as a link.
  def filter_frame(id, &block)
    turbo_frame_tag(id, target: "_top", data: { turbo_action: "advance" }, &block)
  end

  # order.number == 24 -> "#024"
  def order_number(order)
    "##{format('%03d', order.number)}"
  end
end
