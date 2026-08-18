module Finances
  # Auto-books a stock receipt's cost as an expense (docs/PLAN.md D28), so the
  # purchase doesn't have to be re-typed by hand. Skips silently when the part
  # has no purchase_price — there's no cost to book, and nothing back-fills a
  # price added after the fact (known gap, not a bug).
  class LogExpenseFromReceipt
    DEFAULT_CATEGORY = "Закупівля запчастин"

    def self.call(movement) = new(movement).call

    def initialize(movement)
      @movement = movement
    end

    def call
      return unless @movement.receipt?
      return if @movement.part.purchase_price.blank?

      Expense.create!(
        category: DEFAULT_CATEGORY,
        amount: @movement.part.purchase_price * @movement.quantity,
        description: @movement.part.name,
        date: Date.current,
        user: @movement.user,
        stock_movement: @movement
      )
    end
  end
end
