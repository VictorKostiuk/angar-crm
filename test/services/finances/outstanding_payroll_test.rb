require "test_helper"

class Finances::OutstandingPayrollTest < ActiveSupport::TestCase
  setup do
    @client = clients(:ivan)
    @bike = bikes(:trek)
    @owner = users(:owner)
    @mechanic = users(:andrii) # payroll_percent: 35
  end

  def close_order!(price:)
    order = Order.create!(client: @client, bike: @bike, accepted_by: @owner, accepted_at: Time.current,
                           status: :in_progress, mechanic: @mechanic)
    order.order_works.create!(name: "Робота", quantity: 1, price: price)
    order.update!(payment_status: :paid, payment_method: :cash)
    order = Orders::Close.call(order: order)
    raise "close failed: #{order.errors.full_messages}" unless order.closed?

    order.update_column(:closed_at, Time.zone.today.middle_of_day)
    order
  end

  test "obligation minus payouts recorded for the same month" do
    close_order!(price: 1000)

    assert_equal 350, Finances::OutstandingPayroll.call(mechanic: @mechanic)

    @mechanic.payroll_payouts.create!(recorded_by: @owner, amount: 150, period_month: Date.current)
    assert_equal 200, Finances::OutstandingPayroll.call(mechanic: @mechanic)
  end

  test "ignores payouts recorded for a different month" do
    close_order!(price: 1000)
    @mechanic.payroll_payouts.create!(recorded_by: @owner, amount: 999, period_month: 1.month.ago)

    assert_equal 350, Finances::OutstandingPayroll.call(mechanic: @mechanic)
  end
end
