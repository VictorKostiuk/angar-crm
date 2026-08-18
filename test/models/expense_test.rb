require "test_helper"

class ExpenseTest < ActiveSupport::TestCase
  setup do
    @user = users(:owner)
  end

  test "amount must be positive" do
    expense = Expense.new(user: @user, category: "Оренда", amount: 0, date: Date.current)
    assert_not expense.valid?

    expense.amount = 100
    assert expense.valid?
  end

  test "category is required" do
    expense = Expense.new(user: @user, amount: 100, date: Date.current)
    assert_not expense.valid?
    assert expense.errors[:category].present?
  end

  test "auto_logged? reflects whether a stock_movement created it" do
    manual = Expense.create!(user: @user, category: "Оренда", amount: 5000, date: Date.current)
    assert_not manual.auto_logged?
  end
end
