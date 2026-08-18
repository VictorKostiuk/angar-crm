module Orders
  # Single writer of orders.works_total/parts_total/total (docs/PLAN.md §6).
  # Sums already-rounded line totals — never re-multiplies quantity * price —
  # so the order total always matches what the UI shows for each line.
  class RecalculateTotals
    def self.call(order) = new(order).call

    def initialize(order)
      @order = order
    end

    def call
      works_total = @order.order_works.sum(:total)
      parts_total = @order.order_parts.sum(:total)
      total = [ works_total + parts_total - @order.discount, 0 ].max

      @order.update_columns(works_total:, parts_total:, total:)
    end
  end
end
