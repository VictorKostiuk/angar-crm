require "test_helper"

# D56: the mechanic who owns an order earns 2% of the parts fitted on it — the
# brakes they agreed with the client and then replaced. Only orders closed from
# 22.10.2026 count, so months already paid out do not reopen as debt.
class MechanicPartsCommissionTest < ActionDispatch::IntegrationTest
  setup do
    @owner = users(:owner)
    @mechanic = users(:andrii) # 35%
  end

  def close_order!(parts:, works: 0, mechanic: @mechanic, closed_at: Time.zone.today.middle_of_day)
    order = Order.create!(client: clients(:ivan), bike: bikes(:trek), accepted_by: @owner,
                          accepted_at: Time.current, status: :in_progress, mechanic: mechanic)
    order.order_works.create!(name: "Послуга", quantity: 1, price: works, mechanic: mechanic) if works.positive?
    Array(parts).each { |price| order.order_parts.create!(name: "Запчастина", quantity: 1, price: price) }
    order.update!(payment_status: :paid, payment_method: :cash)
    order = Orders::Close.call(order: order)
    order.update_column(:closed_at, closed_at)
    order
  end

  def row(mechanic = @mechanic, range: Date.current.all_month)
    Reports::MechanicStats.new(range: range).row_for(mechanic)
  end

  test "2% of an order's parts goes to the order's mechanic and into earnings" do
    close_order!(parts: [ 2000, 500 ], works: 1000)

    assert_equal 50, row.parts_commission, "2% of 2 500"
    assert_equal row.payout + row.sales_commission + 50, row.earnings
  end

  # Rounded per order, then summed — like the payout minimum — so the total is
  # what each order visibly earned. 3 × (2% of 130) is 3 × 3 = 9; rounding the
  # aggregate instead would give (390 × 2%).round = 8.
  test "commission is rounded per order, not on the period total" do
    3.times { close_order!(parts: 130) }

    assert_equal 9, row.parts_commission
  end

  test "orders closed before the cutoff earn nothing, so paid months stay settled" do
    before = Reports::MechanicStats::PARTS_COMMISSION_SINCE - 1
    close_order!(parts: 5000, closed_at: before.middle_of_day)

    assert_equal 0, row(range: before.all_month).parts_commission
  end

  test "a mechanic on no payroll earns no parts commission either" do
    @owner.update!(works_as_mechanic: true)
    close_order!(parts: 5000, mechanic: @owner)

    assert_equal 0, row(@owner).parts_commission
  end

  test "the mechanic card shows the figure" do
    close_order!(parts: 2500)
    post session_path, params: { email_address: @owner.email_address, password: "password123" }

    get mechanic_path(@mechanic)
    assert_response :success
    assert_select "p", text: "Заробіток із запчастин"
    assert_select "p", text: "50 грн"
  end
end
