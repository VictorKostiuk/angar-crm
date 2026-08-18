require "test_helper"

class Finances::LogExpenseFromReceiptTest < ActiveSupport::TestCase
  setup do
    @part = parts(:kmc_chain) # purchase_price: 500.0
    @user = users(:owner)
  end

  test "auto-creates an expense when a receipt is recorded and the part has a purchase_price" do
    assert_difference -> { Expense.count }, 1 do
      @part.stock_movements.create!(user: @user, kind: :receipt, quantity: 4)
    end

    expense = Expense.order(:created_at).last
    assert_equal 2000, expense.amount
    assert expense.auto_logged?
    assert_equal @user, expense.user
  end

  test "does not create an expense when the part has no purchase_price" do
    @part.update!(purchase_price: nil)

    assert_no_difference -> { Expense.count } do
      @part.stock_movements.create!(user: @user, kind: :receipt, quantity: 4)
    end
  end

  test "does not create an expense for write_off, consumption, or adjustment movements" do
    assert_no_difference -> { Expense.count } do
      @part.stock_movements.create!(user: @user, kind: :adjustment, quantity: -1)
    end
  end
end
