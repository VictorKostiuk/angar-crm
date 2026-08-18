module Parts
  # Single writer of parts.stock_quantity (docs/PLAN.md D26) — sums the
  # immutable stock_movements ledger, never an incremented counter, so a
  # movement inserted by any future code path self-heals the total instead
  # of silently drifting it. Mirrors Orders::RecalculateTotals exactly.
  class RecalculateStock
    def self.call(part) = new(part).call

    def initialize(part)
      @part = part
    end

    def call
      @part.update_column(:stock_quantity, @part.stock_movements.sum(:quantity))
    end
  end
end
