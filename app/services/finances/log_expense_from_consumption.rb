module Finances
  # Auto-books a part's cost as an expense when it's actually used on a job
  # (docs/PLAN.md D28, revised) — cost is recognized at consumption, not at
  # purchase, so it lines up with when the matching revenue (the order's
  # parts_total) is recognized too. Originally triggered on stock receipts;
  # moved here at your request to avoid double-booking a part's cost once at
  # receipt and effectively a second time when it's sold. Skips silently when
  # the part has no purchase_price — there's no cost to book, and nothing
  # back-fills a price added after the fact (known gap, not a bug).
  class LogExpenseFromConsumption
    DEFAULT_CATEGORY = "Витрачені матеріали"

    def self.call(movement) = new(movement).call

    def initialize(movement)
      @movement = movement
    end

    def call
      return unless @movement.consumption?
      return if @movement.part.purchase_price.blank?

      Expense.create!(
        category: DEFAULT_CATEGORY,
        amount: @movement.part.purchase_price * @movement.quantity.abs,
        description: @movement.part.name,
        date: Date.current,
        user: @movement.user,
        stock_movement: @movement
      )
    end
  end
end
