require "test_helper"

# D61: a booking is an Order in «Запис» — made from the calendar, shown in the
# orders list, on the board and (once settled) in Архів, and turned into an
# ordinary «Нове» order when the client walks in.
class BookingsTest < ActionDispatch::IntegrationTest
  MONDAY = Date.new(2026, 11, 2)

  setup do
    travel_to Time.zone.local(2026, 11, 1, 12, 0)
    @owner = users(:owner)
    @mechanic = users(:andrii)
    WorkingHour.create!(weekday: 1, opens_at: "10:00", closes_at: "13:00", slot_minutes: 30, capacity: 1)
    @type = MaintenanceType.create!(name: "Базове ТО", duration_minutes: 60)
  end

  def sign_in(user = @owner)
    post session_path, params: { email_address: user.email_address, password: "password123" }
  end

  def slot(time) = Time.zone.parse("#{MONDAY} #{time}")

  def book!(time = "10:00", **params)
    post bookings_path, params: { client_id: clients(:ivan).id, bike_id: bikes(:trek).id,
                                  maintenance_type_id: @type.id, scheduled_at: slot(time).iso8601 }.merge(params)
    Order.order(:id).last
  end

  test "booking a free slot creates an order in «Запис» with the type's duration" do
    sign_in

    order = assert_difference(-> { Order.count }, 1) { book!("10:00", telegram_username: "@ivan_p", problem: "Скрипить") }

    assert order.booked?
    assert_equal slot("10:00"), order.scheduled_at
    assert_equal 60, order.booking_minutes
    assert_equal @type, order.maintenance_type
    assert_equal "crm", order.booking_channel
    assert_equal "ivan_p", clients(:ivan).reload.telegram_username
    assert_redirected_to bookings_path(month: "2026-11", date: MONDAY)
  end

  test "a taken slot is refused and nothing is saved" do
    sign_in
    book!("10:00")

    assert_no_difference(-> { Order.count }) { book!("10:30") }
    assert_response :unprocessable_entity
    assert_match "цей час уже зайнятий", response.body
  end

  test "a booking with no time picked is refused" do
    sign_in

    assert_no_difference(-> { Order.count }) do
      post bookings_path, params: { client_id: clients(:ivan).id, bike_id: bikes(:trek).id, maintenance_type_id: @type.id }
    end
    assert_response :unprocessable_entity
  end

  test "a new client can be booked straight from the form" do
    sign_in

    assert_difference(-> { Client.count }, 1) do
      book!("11:00", client_id: nil, bike_id: nil, client_name: "Олена", client_phone: "067 555 44 33", bike_name: "Cube")
    end
  end

  test "the calendar shows the day's bookings and the month's counts" do
    sign_in
    book!("10:00")

    get bookings_path(month: "2026-11", date: MONDAY)
    assert_response :success
    assert_select "h2", text: "Листопад 2026"
    assert_match "10:00–11:00", response.body
    assert_match "Базове ТО", response.body
  end

  test "a booking the client made through the bot is marked on the calendar" do
    sign_in
    order = book!("10:00")
    order.update!(booking_channel: "telegram", problem: "Гальма")

    get bookings_path(month: "2026-11", date: MONDAY)
    assert_select "span", text: "Telegram"
    assert_match "Гальма", response.body

    get order_path(order)
    assert_match "через Telegram-бот", response.body
  end

  # D65: a booking made through the bot was missed — it was in the next
  # month's first week, and that month opened on a Sunday showing «Вихідний».
  test "another month opens on its first booking, or else its first working day" do
    sign_in
    post bookings_path, params: { client_id: clients(:ivan).id, bike_id: bikes(:trek).id,
                                  maintenance_type_id: @type.id, scheduled_at: Time.zone.local(2026, 12, 14, 10).iso8601 }

    get bookings_path(month: "2026-12")
    assert_select "h2", text: /14\.12\.2026/

    get bookings_path(month: "2027-01")
    assert_select "h2", { text: /04\.01\.2027/ }, "no bookings: the first Monday, the only day open"

    get bookings_path(month: "2026-11")
    assert_select "h2", { text: /01\.11\.2026/ }, "this month still opens on today, even a day off"
  end

  test "a dimmed day from the next month opens that month on that day" do
    sign_in

    get bookings_path(month: "2026-10")
    assert_select "a[href=?]", bookings_path(month: "2026-11", date: Date.new(2026, 11, 1))
  end

  test "the next bookings are listed whatever month is open" do
    sign_in
    book!("10:00").update!(booking_channel: "telegram")
    book!("11:00").update_column(:status, Order.statuses[:intake])
    book!("12:00").update_column(:status, Order.statuses[:cancelled])
    post bookings_path, params: { client_id: clients(:ivan).id, bike_id: bikes(:trek).id,
                                  maintenance_type_id: @type.id, scheduled_at: Time.zone.local(2026, 12, 14, 10).iso8601 }

    get bookings_path(month: "2026-10")

    cards = css_select("#upcoming_bookings a").map { |card| card.text.squish }
    assert_equal 2, cards.size, "neither the one whose client arrived nor the cancelled one"
    assert_match "Завтра, 10:00–11:00", cards.first
    assert_match "Telegram", cards.first
    assert_match "Пн. 14.12, 10:00–11:00", cards.last
  end

  test "the slots frame offers only free times" do
    sign_in
    book!("10:00")

    get slots_bookings_path(date: MONDAY, maintenance_type_id: @type.id)
    offered = css_select("input[name=scheduled_at]").map { |input| Time.zone.parse(input["value"]).strftime("%H:%M") }
    assert_equal %w[ 11:00 11:30 12:00 ], offered
  end

  test "«Клієнт приїхав» turns the booking into «Нове», accepted now by whoever is at the counter" do
    sign_in
    order = book!("10:00")
    sign_in @mechanic
    travel_to slot("10:05")

    patch order_arrival_path(order)

    order.reload
    assert order.intake?
    assert_equal @mechanic, order.accepted_by
    assert_equal slot("10:05"), order.accepted_at
    assert order.via_booking?, "still remembers it came through a booking"
  end

  test "an order cannot be moved into «Запис» from the status modal" do
    order = Order.create!(client: clients(:ivan), bike: bikes(:trek), accepted_by: @owner, accepted_at: Time.current)

    result = Orders::ChangeStatus.call(order: order, status: :booked, user: @owner)
    assert result.errors[:status].any?
    assert order.reload.intake?
  end

  test "a booking cannot be closed before the bike arrives" do
    sign_in
    order = book!("10:00")

    assert_includes Orders::Close.new(order: order).blockers, "Клієнт ще не приїхав — спершу позначте прийом велосипеда"
  end

  test "a booked bike is not «У майстерні» and is not work in hand" do
    sign_in
    book!("10:00").update!(mechanic: @mechanic)

    assert_not bikes(:trek).in_shop?
    assert_equal 0, Reports::MechanicStats.new(range: Date.current.all_month).row_for(@mechanic).in_progress_count
  end

  test "«Запис» appears in the status filter and the board, and the booking filter reaches Архів" do
    sign_in
    booked = book!("10:00")
    walk_in = Order.create!(client: clients(:ivan), bike: bikes(:trek), accepted_by: @owner, accepted_at: Time.current)
    cancelled = book!("11:00")
    cancelled.update!(status: :cancelled, cancelled_at: Time.current, cancel_reason: "Не приїхав")

    get orders_path
    assert_select "select[name=status] option[value=booked]", text: "Запис"

    get orders_path(status: "booked")
    assert_select "a[href=?]", order_path(booked)
    assert_select "a[href=?]", order_path(walk_in), count: 0

    get orders_path(status: "archive", source: "booking")
    assert_select "a[href=?]", order_path(cancelled)

    get orders_path(source: "walk_in")
    assert_select "a[href=?]", order_path(walk_in)
    assert_select "a[href=?]", order_path(booked), count: 0

    get root_path
    assert_select "[data-status=booked]"
  end

  test "the order page shows the appointment and the client's Telegram" do
    sign_in
    order = book!("10:00", telegram_username: "ivan_p")

    get order_path(order)
    assert_select "a[href=?]", "https://t.me/ivan_p", text: "@ivan_p"
    assert_match "Запис на 02.11.2026 10:00–11:00", response.body
    assert_select "form[action=?]", order_arrival_path(order)
  end

  test "a malformed Telegram nick is refused" do
    sign_in

    assert_no_difference(-> { Order.count }) { book!("10:00", telegram_username: "not a nick!") }
    assert_match "недійсний Telegram-нік", response.body
  end
end
