module Sales
  # Single writer of sales.total — sums the already-rounded line totals rather
  # than re-multiplying quantity * price, so the sale total always matches what
  # the UI shows per line. Mirrors Orders::RecalculateTotals exactly.
  class RecalculateTotal
    def self.call(sale) = new(sale).call

    def initialize(sale)
      @sale = sale
    end

    def call
      @sale.update_column(:total, @sale.sale_items.sum(:total))
    end
  end
end
