require "test_helper"

class FinancesBreakdownTest < ActionDispatch::IntegrationTest
  setup do
    @owner = users(:owner)
    @mechanic = users(:andrii)
    post session_path, params: { email_address: @owner.email_address, password: "password123" }
  end

  def close_order!(works:, parts:)
    order = Order.create!(client: clients(:ivan), bike: bikes(:trek), accepted_by: @owner,
                          accepted_at: Time.current, status: :in_progress, mechanic: @mechanic)
    order.order_works.create!(name: "Послуга", quantity: 1, price: works)
    order.order_parts.create!(name: "Запчастина", quantity: 1, price: parts)
    order.update!(payment_status: :paid, payment_method: :cash)
    order = Orders::Close.call(order: order)
    order.update_column(:closed_at, Time.zone.today.middle_of_day)
    order
  end

  test "an empty period says so rather than showing a bare table" do
    get finances_path(period: "month")

    assert_response :success
    assert_select "td", text: "За цей період немає закритих замовлень."
  end

  # ClosedRevenue carries an explicit warning (D30) that Фінанси and Звіти must
  # never disagree about what revenue means. This table sits directly under the
  # Дохід tile, so its columns have to add up to it.
  test "the breakdown columns sum to the Дохід tile" do
    a = close_order!(works: 500, parts: 250)
    b = close_order!(works: 1000, parts: 400)

    get finances_path(period: "month")
    assert_response :success

    [ a, b ].each do |order|
      assert_select "tbody a", text: "##{format('%03d', order.number)}"
    end

    revenue = Reports::ClosedRevenue.call(range: Date.current.all_month)
    assert_equal 2150, revenue[:works_total] + revenue[:parts_total]

    assert_select "tfoot td", text: money(1500)  # 500 + 1000 послуги
    assert_select "tfoot td", text: money(650)   # 250 + 400 запчастини
    assert_select "tfoot td", text: money(2150)  # == Дохід
    assert_select ".grid p", text: money(2150)   # the tile itself
  end

  test "orders closed outside the period stay out of the table" do
    old = close_order!(works: 900, parts: 100)
    old.update_column(:closed_at, 3.months.ago)
    close_order!(works: 100, parts: 0)

    get finances_path(period: "month")

    assert_select "tbody a", text: "##{format('%03d', old.number)}", count: 0
    assert_select "tfoot td", text: money(100)
  end

  private
    def money(amount) = ApplicationController.helpers.money(amount)
end
