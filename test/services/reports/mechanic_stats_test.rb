require "test_helper"

class Reports::MechanicStatsTest < ActiveSupport::TestCase
  setup do
    @client = clients(:ivan)
    @bike = bikes(:trek)
    @owner = users(:owner)
    @mechanic_a = users(:andrii)
    @mechanic_b = User.create!(name: "Богдан", email_address: "bogdan@fixtures.test", password: "password123",
                                role: :mechanic, payroll_percent: 40, active: true)
    @range = Time.zone.today.all_month
  end

  # Builds+closes an order with the given work lines, then backdates closed_at
  # (Orders::Close always sets it to Time.current) so period-boundary tests
  # can place it inside or outside @range.
  def close_order!(mechanic:, closed_at:, works: [])
    order = Order.create!(client: @client, bike: @bike, accepted_by: @owner, accepted_at: Time.current,
                           status: :in_progress, mechanic: mechanic)
    works.each { |attrs| order.order_works.create!(**attrs) }
    order.update!(payment_status: :paid, payment_method: :cash)
    order = Orders::Close.call(order: order)
    raise "close failed: #{order.errors.full_messages}" unless order.closed?

    order.update_column(:closed_at, closed_at)
    order.reload
  end

  test "payroll base groups work lines by their own mechanic_id, not the order's mechanic_id" do
    order = Order.create!(client: @client, bike: @bike, accepted_by: @owner, accepted_at: Time.current,
                           status: :in_progress, mechanic: @mechanic_a)
    order.order_works.create!(name: "Робота A", quantity: 1, price: 300) # inherits mechanic_a from the order
    order.order_works.create!(name: "Робота B", quantity: 1, price: 200, mechanic: @mechanic_b) # explicit cross-attribution
    order.update!(payment_status: :paid, payment_method: :cash)
    order = Orders::Close.call(order: order)
    assert order.closed?
    order.update_column(:closed_at, Time.zone.today.middle_of_day)

    stats = Reports::MechanicStats.new(range: @range)
    row_a = stats.row_for(@mechanic_a)
    row_b = stats.row_for(@mechanic_b)

    assert_equal 300, row_a.works_total, "A's payroll base must exclude B's cross-attributed line"
    assert_equal 200, row_b.works_total, "B must be credited for the line even though the order belongs to A"
    assert_equal 1, row_a.completed_count # order ownership -> counted for A
    assert_equal 0, row_b.completed_count # B didn't own the order, just contributed one line
  end

  test "excludes orders closed outside the period" do
    close_order!(mechanic: @mechanic_a, closed_at: Time.zone.today.middle_of_day,
                 works: [ { name: "У межах періоду", quantity: 1, price: 500 } ])
    close_order!(mechanic: @mechanic_a, closed_at: 2.months.ago,
                 works: [ { name: "Поза періодом", quantity: 1, price: 999 } ])

    row = Reports::MechanicStats.new(range: @range).row_for(@mechanic_a)

    assert_equal 500, row.works_total
    assert_equal 1, row.completed_count
  end

  test "excludes cancelled orders even with a stale closed_at" do
    order = Order.create!(client: @client, bike: @bike, accepted_by: @owner, accepted_at: Time.current,
                           status: :in_progress, mechanic: @mechanic_a)
    order.order_works.create!(name: "Робота", quantity: 1, price: 700)
    order.update_columns(status: "cancelled", cancelled_at: Time.current, cancel_reason: "тест",
                          closed_at: Time.zone.today.middle_of_day)

    row = Reports::MechanicStats.new(range: @range).row_for(@mechanic_a)

    assert_equal 0, row.works_total
    assert_equal 0, row.completed_count
  end

  test "payout is works_total times payroll_percent, zero for a 0% mechanic" do
    close_order!(mechanic: @mechanic_a, closed_at: Time.zone.today.middle_of_day,
                 works: [ { name: "Робота", quantity: 1, price: 1000 } ])
    zero_pct = User.create!(name: "Нуль", email_address: "zero@fixtures.test", password: "password123",
                             role: :mechanic, payroll_percent: 0, active: true)
    close_order!(mechanic: zero_pct, closed_at: Time.zone.today.middle_of_day,
                 works: [ { name: "Робота", quantity: 1, price: 1000 } ])

    stats = Reports::MechanicStats.new(range: @range)
    assert_equal 350, stats.row_for(@mechanic_a).payout # andrii fixture is 35%
    assert_equal 0, stats.row_for(zero_pct).payout
  end

  test "in_progress_count is live, not period-scoped" do
    Order.create!(client: @client, bike: @bike, accepted_by: @owner, accepted_at: 6.months.ago,
                   status: :in_progress, mechanic: @mechanic_a)

    row = Reports::MechanicStats.new(range: @range).row_for(@mechanic_a)

    assert_equal 1, row.in_progress_count
  end

  test "accepted_count counts by accepted_by regardless of eventual status" do
    Order.create!(client: @client, bike: @bike, accepted_by: @mechanic_a, accepted_at: Time.zone.today.middle_of_day,
                   status: :intake)

    row = Reports::MechanicStats.new(range: @range).row_for(@mechanic_a)

    assert_equal 1, row.accepted_count
  end
end
