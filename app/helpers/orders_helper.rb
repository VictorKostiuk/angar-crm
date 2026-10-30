module OrdersHelper
  # The "your bike is ready" text a mechanic copies out of the order page and
  # sends to the client by hand (P9.3 without a provider: the SMS/Viber/Telegram
  # integration is still blocked on picking one, but the message itself is the
  # part that was actually missing).
  #
  # Assembled from blocks rather than one interpolated template string: an order
  # can have works but no parts (or neither), and a discount only sometimes — a
  # single template would leave dangling headers and stray blank lines. Empty
  # blocks drop out, and the survivors are joined by one blank line each.
  def order_ready_message(order)
    blocks = [
      [ t("ready_message.greeting", name: client_first_name(order.client)) ],
      [ t("ready_message.ready", bike: order.bike.name) ],
      ready_message_section(order.order_works, t("ready_message.works_header")),
      ready_message_section(order.order_parts, t("ready_message.parts_header")),
      ready_message_totals(order),
      [ t("ready_message.closing") ]
    ]

    blocks.reject(&:blank?).map { |block| block.join("\n") }.join("\n\n")
  end

  # The «Очікує погодження» message: what the mechanic found and recommends,
  # with prices, for the client to agree to before work starts. Same block
  # assembly as order_ready_message, so an order with no parts yet simply has
  # no materials section.
  def order_approval_message(order)
    blocks = [
      [ t("ready_message.greeting", name: client_first_name(order.client)) ],
      [ t("approval_message.inspected", bike: order.bike.name) ],
      ready_message_section(order.order_works, t("approval_message.works_header")),
      ready_message_section(order.order_parts, t("approval_message.parts_header")),
      ready_message_totals(order, total_key: "approval_message.total"),
      [ t("approval_message.closing") ]
    ]

    blocks.reject(&:blank?).map { |block| block.join("\n") }.join("\n\n")
  end

  private
    def ready_message_section(lines, header)
      return [] if lines.none?

      [ header, *lines.map { |line| ready_message_line(line) } ]
    end

    # Each line carries its own sum so the total below is self-explaining, and
    # the quantity is spelled out only when it isn't 1 — "× 1" is noise on the
    # single-item line that most of them are. Formatted the same way the
    # read-only table cells do it, so the message and the screen never disagree.
    def ready_message_line(line)
      amount = money(line.total)
      return t("ready_message.line", name: line.name, amount: amount) if line.quantity == 1

      quantity = number_with_precision(line.quantity, precision: 2, strip_insignificant_zeros: true)
      t("ready_message.line_with_quantity", name: line.name, quantity: quantity, amount: amount)
    end

    # order.total is already net of the discount (Orders::RecalculateTotals),
    # so the two lines need no arithmetic of their own.
    def ready_message_totals(order, total_key: "ready_message.total")
      lines = []
      lines << t("ready_message.discount", amount: money(order.discount)) if order.discount.positive?
      lines << t(total_key, amount: money(order.total))
      lines
    end

    # Clients are stored with a full name; a message that opens "Добрий день,
    # Іван Петренко" reads like a bank letter. Falls back to the whole string
    # for a single-token name.
    def client_first_name(client)
      client.first_name
    end
end
