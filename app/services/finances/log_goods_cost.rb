module Finances
  # Auto-books a part's cost as an expense at the moment it leaves stock for
  # money (docs/PLAN.md D28, revised; D41 adds sales) — cost is recognized when
  # the matching revenue is, not at purchase. Two events qualify:
  #
  #   consumption — used on an order, revenue is the order's parts_total
  #   sale        — sold over the counter, revenue is the sale's total
  #
  # A write-off or an adjustment books nothing here: no revenue accompanies it.
  # Skips silently when the part has no purchase_price — there's no cost to
  # book; Part#backfill_missed_expenses catches those up if a price is set later.
  class LogGoodsCost
    CATEGORIES = { "consumption" => "Витрачені матеріали", "sale" => "Собівартість продажу" }.freeze

    def self.call(movement) = new(movement).call

    def initialize(movement)
      @movement = movement
    end

    def call
      category = CATEGORIES[@movement.kind]
      return if category.blank?
      return if @movement.part.purchase_price.blank?

      Expense.create!(
        category: category,
        amount: @movement.part.purchase_price * @movement.quantity.abs,
        description: @movement.part.name,
        date: Date.current,
        user: @movement.user,
        stock_movement: @movement
      )
    end
  end
end
