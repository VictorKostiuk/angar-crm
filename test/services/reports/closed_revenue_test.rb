require "test_helper"

class Reports::ClosedRevenueTest < ActiveSupport::TestCase
  setup do
    @client = clients(:ivan)
    @bike = bikes(:trek)
    @owner = users(:owner)
    @mechanic = users(:andrii)
    @range = Time.zone.today.all_month
  end

  def close_order!(mechanic:, price:)
    order = Order.create!(client: @client, bike: @bike, accepted_by: @owner, accepted_at: Time.current,
                           status: :in_progress, mechanic: mechanic)
    order.order_works.create!(name: "Робота", quantity: 1, price: price)
    order.order_parts.create!(name: "Деталь", quantity: 1, price: 100)
    order.update!(payment_status: :paid, payment_method: :cash)
    order = Orders::Close.call(order: order)
    raise "close failed: #{order.errors.full_messages}" unless order.closed?

    order.update_column(:closed_at, Time.zone.today.middle_of_day)
    order
  end

  test "sums works/parts totals across closed orders regardless of mechanic, and counts orders" do
    close_order!(mechanic: @mechanic, price: 300)
    other_mechanic = User.create!(name: "Богдан", email_address: "bogdan@fixtures.test", password: "password123",
                                   role: :mechanic, payroll_percent: 40, active: true)
    close_order!(mechanic: other_mechanic, price: 500)

    totals = Reports::ClosedRevenue.call(range: @range)

    assert_equal 800, totals[:works_total]
    assert_equal 200, totals[:parts_total]
    assert_equal 2, totals[:order_count]
  end

  test "does not silently drop an order whose mechanic_id is not actually a mechanic (D30)" do
    close_order!(mechanic: @owner, price: 400)

    totals = Reports::ClosedRevenue.call(range: @range)

    assert_equal 400, totals[:works_total]
    assert_equal 1, totals[:order_count]
    assert_equal 0, Reports::MechanicStats.new(range: @range).call.sum(&:total),
      "sanity check: MechanicStats-based summing would have missed this order entirely"
  end

  test "excludes open and cancelled orders, and orders closed outside the range" do
    order = Order.create!(client: @client, bike: @bike, accepted_by: @owner, accepted_at: Time.current,
                           status: :in_progress, mechanic: @mechanic)
    order.order_works.create!(name: "Робота", quantity: 1, price: 999)

    close_order!(mechanic: @mechanic, price: 250).update_column(:closed_at, 2.months.ago)

    totals = Reports::ClosedRevenue.call(range: @range)

    assert_equal 0, totals[:works_total]
    assert_equal 0, totals[:order_count]
  end
end
