require "test_helper"

# Commission on counter sales used to be computed, subtracted from profit on
# Фінанси, and then owed to nobody: Reports::MechanicStats knew only about
# order works and parts, so no mechanic page showed it and no balance settled
# it. These lock in that it now reaches the person who earned it.
class MechanicSalesCommissionTest < ActionDispatch::IntegrationTest
  setup do
    @owner = users(:owner)
    @mechanic = users(:andrii)
    @mechanic.update!(sales_percent: 5)
    @part = parts(:kmc_chain)
    StockMovement.create!(part: @part, kind: :receipt, quantity: 50, user: @owner)

    post session_path, params: { email_address: @owner.email_address, password: "password123" }
  end

  def money(amount) = ApplicationController.helpers.money(amount)

  # sales.total is written by Sales::RecalculateTotal after save, the same way
  # SalesController#create does it — there is no model callback to lean on.
  def sell!(seller: @mechanic, price: 1000, quantity: 1, sold_at: Time.current)
    sale = Sale.create!(sold_by: seller, sold_at: sold_at,
                        sale_items_attributes: [ { part_id: @part.id, quantity: quantity, price: price } ])
    Sales::RecalculateTotal.call(sale)
    sale.reload
  end

  def row(range: Time.zone.today.all_month)
    Reports::MechanicStats.new(range: range).row_for(@mechanic)
  end

  test "the row carries this seller's sales for the period and nobody else's" do
    sell!(price: 1000)
    sell!(price: 2000)
    sell!(seller: @owner, price: 5000)
    sell!(sold_at: 2.months.ago)

    assert_equal 3000, row.sales_total, "another seller's and another month's sales must not count"
    assert_equal 150, row.sales_commission, "5% of 3 000"
  end

  # The number on the mechanic's card has to be the same number Продажі shows
  # for that seller and period. Commission rounds per sale, so summing the
  # rounded figures and rounding the summed total are not the same arithmetic —
  # 3 × (333 × 5%) is 3 × 17 = 51, but (999 × 5%).round is 50.
  test "the card's commission equals what Продажі adds up for the same seller" do
    3.times { sell!(price: 333) }

    from_sales_page = Sale.in_range(Time.zone.today.all_month)
                          .where(sold_by: @mechanic).includes(:sold_by).sum(&:commission)

    assert_equal 51, row.sales_commission, "per-sale rounding, not a rounded aggregate"
    assert_equal from_sales_page, row.sales_commission
  end

  test "earnings add the commission to the works payout, and the debt settles both" do
    order = Order.create!(client: clients(:ivan), bike: bikes(:trek), accepted_by: @owner,
                          accepted_at: Time.current, status: :in_progress, mechanic: @mechanic)
    order.order_works.create!(name: "Робота", quantity: 1, price: 1000)
    order.update!(payment_status: :paid, payment_method: :cash)
    Orders::Close.call(order: order)
    sell!(price: 2000)

    assert_equal 350, row.payout, "works payout stays works-only (D33)"
    assert_equal 100, row.sales_commission
    assert_equal 450, row.earnings

    debt = Finances::MechanicDebt.new(mechanic: @mechanic).call.first
    assert_equal 450, debt.earned, "commission is money owed, not a display-only figure"
    assert_equal 450, debt.balance

    assert_equal 450, Finances::OutstandingPayroll.call(mechanic: @mechanic, month: Date.current)
  end

  # The payout modal prefills from the same figure, or the owner would pay the
  # labour and silently drop the commission.
  test "the payout form prefills the commission along with the labour" do
    sell!(price: 2000)

    get new_mechanic_payroll_payout_path(@mechanic, month: Date.current), headers: { "Turbo-Frame" => "modal" }

    assert_response :success
    assert_select "input[name=?][value=?]", "payroll_payout[amount]", "100.0"
  end

  test "the mechanic card and the roster show the sales figures" do
    sell!(price: 2000)

    get mechanic_path(@mechanic, period: "month")
    assert_select "p", text: "Комісія з продажів"
    assert_select "p", text: "Всього зароблено"
    assert_select "p", text: money(100)

    get mechanics_path(period: "month")
    assert_select "p", text: "Комісія з продажів"
    assert_select "p", text: "5%"
  end

  # A shop that pays no commission should not carry empty sales tiles on every
  # mechanic card forever — the block appears the moment a rate is set.
  test "the sales block stays hidden for a mechanic with no rate and no sales" do
    @mechanic.update!(sales_percent: 0)

    get mechanic_path(@mechanic, period: "month")
    assert_select "p", text: "Комісія з продажів", count: 0

    get mechanics_path(period: "month")
    assert_select "p", text: "Комісія з продажів", count: 0
  end

  test "the payroll tables carry the commission and the combined total" do
    sell!(price: 2000)

    get finances_path(period: "month")
    assert_select "th", text: "Комісія з продажів"
    assert_select "th", text: "Всього"
    assert_select "tbody td", text: money(100)
  end
end
