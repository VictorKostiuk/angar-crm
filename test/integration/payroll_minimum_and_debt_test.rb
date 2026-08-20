require "test_helper"

class PayrollMinimumAndDebtTest < ActionDispatch::IntegrationTest
  setup do
    @owner = users(:owner)
    @mechanic = users(:andrii) # 35%
    post session_path, params: { email_address: @owner.email_address, password: "password123" }
  end

  def close_order!(works:, parts: 0, mechanic: @mechanic)
    order = Order.create!(client: clients(:ivan), bike: bikes(:trek), accepted_by: @owner,
                          accepted_at: Time.current, status: :in_progress, mechanic: mechanic)
    order.order_works.create!(name: "Послуга", quantity: 1, price: works, mechanic: mechanic) if works.positive?
    order.order_parts.create!(name: "Запчастина", quantity: 1, price: parts) if parts.positive?
    order.update!(payment_status: :paid, payment_method: :cash)
    order = Orders::Close.call(order: order)
    order.update_column(:closed_at, Time.zone.today.middle_of_day)
    order
  end

  def row = Reports::MechanicStats.new(range: Date.current.all_month).row_for(@mechanic)

  # D37: the minimum is per order. Flooring the period aggregate instead would
  # pay it once no matter how many small orders were done.
  test "each order earns at least the minimum, and the floors add up" do
    3.times { close_order!(works: 100) } # 35 грн each before the floor

    assert_equal 300, row.works_total
    assert_equal 300, row.payout, "three floored orders, not one"
  end

  test "an order above the minimum is paid at the percentage" do
    close_order!(works: 1000) # 350

    assert_equal 350, row.payout
  end

  test "the floor and the percentage mix per order" do
    close_order!(works: 100)   # 35  -> 100
    close_order!(works: 1000)  # 350 -> 350

    assert_equal 450, row.payout
  end

  # The floor guarantees a minimum on labour performed, not on orders touched.
  test "an order with no services of theirs earns nothing" do
    close_order!(works: 0, parts: 2900)

    assert_equal 0, row.works_total
    assert_equal 0, row.payout
    assert_equal 1, row.completed_count, "they still own the order"
  end

  # A 0% mechanic is explicitly on no payroll (D12) — the floor must not
  # manufacture earnings for them.
  test "a mechanic on 0% earns nothing, minimum included" do
    @mechanic.update!(payroll_percent: 0)
    close_order!(works: 1000)

    assert_equal 0, row.payout
  end

  test "the mechanic card and roster show the floored figure" do
    3.times { close_order!(works: 100) }

    get mechanic_path(@mechanic, period: "month")
    assert_select "p", text: ApplicationController.helpers.money(300)

    get mechanics_path(period: "month")
    assert_select "p", text: "35% від послуг"
  end

  # ── Каталог для механіка (D38) ─────────────────────────────────────────────
  test "a mechanic can open and maintain the catalogs" do
    post session_path, params: { email_address: @mechanic.email_address, password: "password123" }

    get root_path
    assert_select "nav a[href=?]", services_path, text: "Послуги"
    assert_select "nav a[href=?]", parts_path, text: "Запчастини"

    get services_path
    assert_response :success
    get parts_path
    assert_response :success

    category = Category.part.active.first
    assert_difference -> { Part.count }, 1 do
      post parts_path, params: { part: { name: "Втулка", base_price: 250, category_id: category.id } }
    end

    # The "+ категорія" button lives on those pages, so it has to work there too.
    assert_difference -> { Category.count }, 1 do
      post categories_path, params: { category: { name: "Втулки", kind: "part" } }
    end
  end

  test "opening the catalogs did not open the owner-only screens" do
    post session_path, params: { email_address: @mechanic.email_address, password: "password123" }

    get suppliers_path
    assert_redirected_to root_path

    get users_path
    assert_redirected_to root_path

    get finances_path
    assert_redirected_to root_path
  end

  # ── Статистика ─────────────────────────────────────────────────────────────
  test "статистика splits services from parts" do
    close_order!(works: 1000, parts: 400)

    get statistics_path(period: "month")

    assert_response :success
    assert_select "p", text: "Послуги"
    assert_select "p", text: "Запчастини"
    assert_select "p", text: ApplicationController.helpers.money(1000)
    assert_select "p", text: ApplicationController.helpers.money(400)
    assert_select "p", text: ApplicationController.helpers.money(1400)
    assert_select "p", text: "послуги + запчастини"
  end

  # ── Борг ───────────────────────────────────────────────────────────────────
  test "debt is earned-minus-paid across all time, not the selected period" do
    close_order!(works: 1000)                 # 350 earned
    @mechanic.payroll_payouts.create!(recorded_by: @owner, amount: 100, period_month: Date.current)

    debt = Finances::MechanicDebt.new(mechanic: @mechanic).call.first
    assert_equal 350, debt.earned
    assert_equal 100, debt.paid
    assert_equal 250, debt.balance
    assert debt.owed?

    # A period filter that excludes the order must not change the balance.
    get finances_path(period: "day", from: 3.years.ago.to_date, to: 3.years.ago.to_date)
    assert_select "p", text: ApplicationController.helpers.money(250)
    assert_select "p", text: "За весь час, не за обраний період."
  end

  # One mechanic's overpayment must not cancel out what the shop owes another.
  test "the total counts only what is still owed" do
    close_order!(works: 1000)                 # @mechanic earns 350
    @mechanic.payroll_payouts.create!(recorded_by: @owner, amount: 100, period_month: Date.current)

    over = users(:owner).tap { |u| u.update!(works_as_mechanic: true, payroll_percent: 10) }
    close_order!(works: 1000, mechanic: over) # earns 100
    over.payroll_payouts.create!(recorded_by: @owner, amount: 900, period_month: Date.current)

    assert_equal(-800, Finances::MechanicDebt.new(mechanic: over).call.first.balance)
    assert_equal 250, Finances::MechanicDebt.new.total, "an overpayment must not offset another's debt"
  end

  test "the mechanic card shows the standing balance with its derivation" do
    close_order!(works: 1000)
    @mechanic.payroll_payouts.create!(recorded_by: @owner, amount: 100, period_month: Date.current)

    get mechanic_path(@mechanic, period: "month")

    assert_select "p", text: /Борг за весь час/
    assert_select "span", text: /зароблено .*350.*виплачено .*100/m
  end
end
