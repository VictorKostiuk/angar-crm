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

  # Звіти used to compute revenue the same way Фінанси does precisely so the two
  # screens could never disagree (D30). Merged onto one page, that becomes:
  # with default filters, zone 2's Загальний чек must equal zone 1's Дохід.
  test "with default filters the breakdown agrees with the P&L above it" do
    close_order!(works: 500, parts: 250)
    close_order!(works: 1000, parts: 400)

    get finances_path(period: "month")

    assert_select "p", text: money(2150), minimum: 2 # Дохід and Загальний чек
    assert_select "p", text: "Загальний чек"
    assert_select "p", text: "Дохід із замовлень"
  end

  # Sales and rentals are separate revenue lines on purpose. If they were folded
  # into Дохід, it would stop equalling ClosedRevenue and the zone agreement
  # above would break silently (D30).
  test "sales and rental money never leak into the orders revenue figure" do
    close_order!(works: 500, parts: 250)

    part = Part.create!(name: "Камера", category: Category.part.active.first, base_price: 180)
    StockMovement.create!(part: part, kind: :receipt, quantity: 5, user: @owner)
    sale = Sale.create!(sold_by: @owner, sold_at: Time.current,
                        sale_items_attributes: [ { part_id: part.id, quantity: 1, price: 180 } ])
    Sales::RecalculateTotal.call(sale)

    bike = RentalBike.create!(name: "Trek прокат", daily_rate: 300)
    Rental.create!(rental_bike: bike, issued_by: @owner, renter_name: "Гість",
                   rented_from: Date.current, rented_to: Date.current + 2)

    get finances_path(period: "month")

    # Read each tile by its own label — asserting the number appears *somewhere*
    # on the page passes even when sales are folded into Дохід, because the
    # breakdown below still shows the orders-only figure.
    assert_equal money(750), tile_value("Дохід із замовлень")
    assert_equal money(180), tile_value("Продажі")
    assert_equal money(600), tile_value("Прокат")
    assert_equal money(750), tile_value("Загальний чек")
    assert_equal 750, Reports::ClosedRevenue.call(range: Date.current.all_month).values_at(:works_total, :parts_total).sum
  end

  # The P&L is period-only on purpose: expenses can't be attributed to a
  # mechanic, so scoping those tiles would break Дохід − Витрати = Прибуток.
  test "a mechanic filter narrows the breakdown but never the P&L" do
    close_order!(works: 500, parts: 250)                          # @mechanic
    other = users(:owner).tap { |u| u.update!(works_as_mechanic: true, payroll_percent: 10) }
    order = close_order!(works: 1000, parts: 0)
    order.update!(mechanic: other)

    get finances_path(period: "month", mechanic_id: @mechanic.id)

    assert_select "p", text: money(1750)  # Дохід — still shop-wide
    assert_select "p", text: money(750)   # Загальний чек — just this mechanic
    assert_select "tfoot td", text: money(1750), minimum: 1
  end

  test "the status filter reaches the breakdown only" do
    close_order!(works: 500, parts: 250)
    Order.create!(client: clients(:ivan), bike: bikes(:trek), accepted_by: @owner,
                  accepted_at: Time.current, status: :in_progress, mechanic: @mechanic)
      .order_works.create!(name: "Послуга", quantity: 1, price: 999)

    get finances_path(period: "month", status: "in_progress")

    assert_select "p", text: money(750)  # Дохід — closed orders only, unchanged
    assert_select "p", text: money(999)  # Загальний чек — the in-progress order
  end

  # §7: an admin gets revenue but never individual payouts.
  test "an admin sees the breakdown but not the payroll table" do
    admin = User.create!(name: "Адмін", email_address: "admin@fixtures.test",
                         password: "password123", role: :admin)
    close_order!(works: 500, parts: 250)

    post session_path, params: { email_address: admin.email_address, password: "password123" }
    get finances_path(period: "month")

    assert_response :success
    assert_select "h2", text: "Доходи по механіках"
    assert_select "h2", text: "Розрахунок виробітки механіків", count: 0
    assert_select "p", text: "Виплати механікам", count: 0
    assert_select "p", text: "Чистий прибуток", count: 0
  end

  test "the retired Звіти page is gone from the routes and the sidebar" do
    get finances_path
    assert_select "nav a", text: "Звіти", count: 0

    get "/reports"
    assert_response :not_found
  end

  private
    def money(amount) = ApplicationController.helpers.money(amount)

    # The value <p> sitting next to the label <p> inside the same tile.
    def tile_value(label)
      tile = Nokogiri::HTML5(response.body).css("div").find do |div|
        div.css("> p").any? { |p| p.text.strip == label }
      end
      raise Minitest::Assertion, "no tile labelled #{label.inspect}" unless tile

      tile.css("> p")[1]&.text&.strip
    end
end
