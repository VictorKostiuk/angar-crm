require "test_helper"

class PayrollPayoutTest < ActiveSupport::TestCase
  setup do
    @mechanic = users(:andrii)
    @owner = users(:owner)
  end

  test "amount must be positive" do
    payout = PayrollPayout.new(user: @mechanic, recorded_by: @owner, amount: 0, period_month: Date.current)
    assert_not payout.valid?

    payout.amount = 1000
    assert payout.valid?
  end

  test "user must be a mechanic" do
    payout = PayrollPayout.new(user: @owner, recorded_by: @owner, amount: 1000, period_month: Date.current)
    assert_not payout.valid?
    assert payout.errors[:user].present?
  end

  test "period_month is normalized to the first of the month" do
    payout = PayrollPayout.create!(user: @mechanic, recorded_by: @owner, amount: 1000, period_month: Date.new(2026, 8, 15))
    assert_equal Date.new(2026, 8, 1), payout.period_month
  end
end
