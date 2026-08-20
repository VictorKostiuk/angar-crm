require "test_helper"

class Finances::LogGoodsCostTest < ActiveSupport::TestCase
  setup do
    @part = parts(:kmc_chain) # purchase_price: 500.0
  end

  test "auto-creates an expense when a part is consumed and has a purchase_price" do
    assert_difference -> { Expense.count }, 1 do
      @part.stock_movements.create!(kind: :consumption, quantity: -4)
    end

    expense = Expense.order(:created_at).last
    assert_equal 2000, expense.amount
    assert expense.auto_logged?
    assert_nil expense.user
  end

  test "does not create an expense when the part has no purchase_price" do
    @part.update!(purchase_price: nil)

    assert_no_difference -> { Expense.count } do
      @part.stock_movements.create!(kind: :consumption, quantity: -4)
    end
  end

  test "does not create an expense for receipt, write_off, or adjustment movements" do
    assert_no_difference -> { Expense.count } do
      @part.stock_movements.create!(user: users(:owner), kind: :receipt, quantity: 4)
    end
  end
end
