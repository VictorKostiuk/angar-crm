module Orders
  # Single writer of orders.works_total/parts_total/discount/discount_source/
  # total (docs/PLAN.md §6). Sums already-rounded line totals — never
  # re-multiplies quantity * price — so the order total always matches what the
  # UI shows for each line.
  #
  # The discount is *derived* here rather than stored by the form (D47): it is
  # re-decided from its source every time the lines change, so a percentage
  # can't freeze at an amount that no longer matches the order.
  class RecalculateTotals
    def self.call(order) = new(order).call

    def initialize(order)
      @order = order
    end

    def call
      works_total = @order.order_works.sum(:total)
      parts_total = @order.order_parts.sum(:total)
      discount = Orders::ApplyDiscount.call(order: @order, works_total:, parts_total:)
      total = [ works_total + parts_total - discount.amount, 0 ].max

      # update_columns writes straight to the row: no callbacks, so deriving the
      # discount here cannot re-trigger this.
      @order.update_columns(works_total:, parts_total:, total:,
                            discount: discount.amount, discount_source: discount.source)
    end
  end
end
