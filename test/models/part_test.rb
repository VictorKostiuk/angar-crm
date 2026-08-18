require "test_helper"

class PartTest < ActiveSupport::TestCase
  setup do
    @category = categories(:chains)
  end

  test "purchase_price is optional but must not be negative when present" do
    part = Part.new(category: @category, name: "Тест", base_price: 100, purchase_price: -1)
    assert_not part.valid?
    assert part.errors[:purchase_price].present?

    part.purchase_price = nil
    assert part.valid?
  end

  test "setting purchase_price backfills expenses for past consumption movements that missed one" do
    part = parts(:kmc_chain) # purchase_price: 500.0
    part.update!(purchase_price: nil)
    movement = part.stock_movements.create!(kind: :consumption, quantity: -2)
    assert_nil movement.reload.expense

    assert_difference -> { Expense.count }, 1 do
      part.update!(purchase_price: 300)
    end

    expense = movement.reload.expense
    assert_equal 600, expense.amount
  end

  test "does not create duplicate expenses for consumption movements that already have one" do
    part = parts(:kmc_chain) # purchase_price: 500.0
    movement = part.stock_movements.create!(kind: :consumption, quantity: -1)
    assert_not_nil movement.reload.expense

    assert_no_difference -> { Expense.count } do
      part.update!(purchase_price: 600)
    end
  end
end
