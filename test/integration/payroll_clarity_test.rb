require "test_helper"

class PayrollClarityTest < ActionDispatch::IntegrationTest
  setup do
    @owner = users(:owner)
    @mechanic = users(:andrii) # payroll_percent: 35
    post session_path, params: { email_address: @owner.email_address, password: "password123" }
  end

  def close_order!(works:, parts:, closed_at: Time.zone.today.middle_of_day)
    order = Order.create!(client: clients(:ivan), bike: bikes(:trek), accepted_by: @owner,
                          accepted_at: Time.current, status: :in_progress, mechanic: @mechanic)
    order.order_works.create!(name: "Послуга", quantity: 1, price: works)
    order.order_parts.create!(name: "Запчастина", quantity: 1, price: parts) if parts.positive?
    order.update!(payment_status: :paid, payment_method: :cash)
    order = Orders::Close.call(order: order)
    order.update_column(:closed_at, closed_at)
    order
  end

  def money(amount) = ApplicationController.helpers.money(amount)

  # D33: the earning base is послуги alone — parts are goods the shop resells,
  # not labour. The card has to show which number the % is taken from, or the
  # arithmetic on screen doesn't check out.
  test "the mechanic card shows the base the earnings are actually taken from" do
    close_order!(works: 1000, parts: 400)

    get mechanic_path(@mechanic, period: "month")

    assert_response :success
    assert_select "p", text: money(1000)          # Послуги == the payout base
    assert_select "p", text: "база для заробітку"
    assert_select "p", text: money(1400)          # Загальна сума, context only
    assert_select "p", text: /із запчастинами #{Regexp.escape(money(400))}/
    assert_select "p", text: money(350)           # 1000 * 35%, NOT 1400 * 35%
    assert_select "p", text: "35% від послуг"
  end

  test "the roster shows the same chain, and it multiplies out" do
    close_order!(works: 1000, parts: 400)

    get mechanics_path(period: "month")

    assert_select "p", text: "Послуги"
    assert_select "p", text: "% заробітку"
    assert_select "p", text: "Заробіток"
    assert_select "p", text: "35% від послуг"

    row = Reports::MechanicStats.call(range: Date.current.all_month).find { |r| r.mechanic == @mechanic }
    assert_equal (row.works_total * 35 / 100).round, row.payout, "Послуги × % must equal Заробіток"
    refute_equal (row.total * 35 / 100).round, row.payout, "parts must not be in the earning base"
  end

  test "the percent field says what it is a percent of" do
    get users_path

    assert_select "label", text: "% заробітку від суми послуг"
    assert_select "p", text: /запчастини в базу не входять/
    assert_select "th", text: "% заробітку"
  end

  test "the payroll tables bill from послуги, not the order total" do
    close_order!(works: 1000, parts: 400)

    get finances_path(period: "month")
    assert_select "th", text: "Послуги"
    assert_select "th", text: "% заробітку"
    assert_select "tbody td", text: money(1000)
    assert_select "tbody td", text: money(350)
  end

  # The modal used to prefill Date.current regardless of the period behind it:
  # viewing an older month offered the current month's figures.
  test "the payout modal follows the month being viewed, not today" do
    last_month = 1.month.ago.to_date.beginning_of_month
    close_order!(works: 1000, parts: 0, closed_at: (last_month + 14.days).middle_of_day)

    get new_mechanic_payroll_payout_path(@mechanic, month: last_month),
        headers: { "Turbo-Frame" => "modal" }

    assert_response :success
    assert_select "input[name=?][value=?]", "payroll_payout[period_month]", last_month.strftime("%Y-%m")
    assert_select "input[name=?][value=?]", "payroll_payout[amount]", "350.0"
    assert_select "dt", text: "Нараховано за #{last_month.strftime('%m.%Y')}"
    assert_select "dd", text: money(350)
  end

  test "the modal shows what is already paid and what is left" do
    close_order!(works: 1000, parts: 0)
    @mechanic.payroll_payouts.create!(recorded_by: @owner, amount: 100, period_month: Date.current)

    get new_mechanic_payroll_payout_path(@mechanic, month: Date.current), headers: { "Turbo-Frame" => "modal" }

    assert_select "dt", text: "Уже виплачено"
    assert_select "dd", text: money(100)
    assert_select "dt", text: "Залишок"
    assert_select "dd", text: money(250)
  end

  # <input type="month"> posts "YYYY-MM", which Active Record typecasts to nil.
  test "a month picker value round-trips instead of blanking the period" do
    assert_difference -> { @mechanic.payroll_payouts.count }, 1 do
      post mechanic_payroll_payouts_path(@mechanic),
           params: { payroll_payout: { amount: "500", period_month: "2026-08" } }
    end

    assert_equal Date.new(2026, 8, 1), @mechanic.payroll_payouts.order(:id).last.period_month
  end

  # period_month is attribution (which month's earnings this settles); paid_on
  # is cash flow (when the money left). They are different dates and both are
  # recorded.
  test "the modal asks for both the earnings month and the payment date" do
    get new_mechanic_payroll_payout_path(@mechanic, month: Date.current), headers: { "Turbo-Frame" => "modal" }

    assert_select "label", text: "За який місяць"
    assert_select "input[type=month][name=?]", "payroll_payout[period_month]"
    assert_select "label", text: "Коли виплачено"
    assert_select "input[type=date][name=?][value=?]", "payroll_payout[paid_on]", Date.current.to_s
  end

  test "a payout paid in a later month still settles the month it was earned in" do
    close_order!(works: 1000, parts: 0, closed_at: 1.month.ago.to_date.beginning_of_month + 14.days)
    earned_month = 1.month.ago.to_date.beginning_of_month

    post mechanic_payroll_payouts_path(@mechanic),
         params: { payroll_payout: { amount: "350", period_month: earned_month.strftime("%Y-%m"),
                                     paid_on: Date.current.to_s } }

    payout = @mechanic.payroll_payouts.order(:id).last
    assert_equal earned_month, payout.period_month
    assert_equal Date.current, payout.paid_on

    # Attribution: the month it was earned in is settled.
    assert_equal 0, Finances::OutstandingPayroll.call(mechanic: @mechanic, month: earned_month)

    # Cash flow: Фінанси counts it in the period the money actually left.
    get finances_path(period: "month")
    assert_select "p", text: money(350)
    assert_select "p", text: "Виплати, здійснені в обраний період."
  end

  test "the payout history leads with when it was paid" do
    @mechanic.payroll_payouts.create!(recorded_by: @owner, amount: 200,
                                      period_month: Date.new(2026, 8, 1), paid_on: Date.new(2026, 9, 3))

    get mechanic_path(@mechanic, period: "month")

    assert_select "span", text: I18n.l(Date.new(2026, 9, 3))
    assert_select "span", text: "за 08.2026"
  end

  test "omitting the payment date records today rather than failing" do
    payout = @mechanic.payroll_payouts.create!(recorded_by: @owner, amount: 100, period_month: Date.current)

    assert_equal Date.current, payout.paid_on
  end

  test "a junk month param falls back instead of blowing up" do
    get new_mechanic_payroll_payout_path(@mechanic, month: "не-дата"), headers: { "Turbo-Frame" => "modal" }

    assert_response :success
    assert_select "dt", text: "Нараховано за #{Date.current.strftime('%m.%Y')}"
  end
end
