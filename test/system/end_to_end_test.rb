require "application_system_test_case"

class EndToEndSystemTest < ApplicationSystemTestCase
  setup { @owner = users(:owner) }

  test "taking in a bike, adding work, paying and closing it" do
    Service.create!(name: "Заміна ланцюга", category: Category.service.active.first, base_price: 250)
    sign_in @owner

    visit root_path
    click_on "+ Нове замовлення"

    fill_in "client_search", with: clients(:ivan).name.split.first
    click_on clients(:ivan).name
    # Selecting a client asynchronously replaces both client and bike fields.
    # Wait for that response before typing a name into the replacement field.
    assert_selector "input[name='client_id'][value='#{clients(:ivan).id}']", visible: :all
    fill_in "bike_name", with: "Trek Marlin"
    fill_in "problem", with: "Скрипить ланцюг"
    click_on "Прийняти велосипед"

    # The problem stays editable while the order is open, so it comes back in
    # its textarea rather than as plain text.
    assert_field "order[problem]", with: "Скрипить ланцюг"

    # Services cannot be added to an order with nobody assigned — the line would
    # belong to no mechanic and count toward no payroll. Pick one first, through
    # the sidebar select, which auto-submits.
    assert_selector "button[disabled]", text: "+ Додати послугу"
    select users(:andrii).name, from: "order[mechanic_id]"
    assert_text "Замовлення оновлено."

    click_on "+ Додати послугу"
    within("turbo-frame#order_work_search_results") { first("button").click }
    assert_text "250 грн"
    # Cuprite hit-tests by coordinates and doesn't model the top layer, so a
    # plain click inside a native <dialog> reports the dialog as an obstruction.
    find("button", text: "Готово").trigger("click")

    click_on "Оплата"
    choose I18n.t("payment_methods.cash")
    find("input[type=submit][value='Позначити оплачено']").trigger("click")
    assert_text "Оплату зафіксовано."
    assert_text "Оплачено"

    # Editing is still open while the order is open.
    assert_selector "a", text: "+ Додати послугу"

    order = Order.order(:id).last
    assert_equal users(:andrii), order.reload.mechanic

    visit order_path(order)
    find("a[title='Закрити замовлення']").click
    find("button", text: "Закрити замовлення").trigger("click")

    assert_text "Замовлення закрито."
    assert_text I18n.t("statuses.order.closed")
    # ...and shut once it is settled.
    assert_no_selector "a", text: "+ Додати послугу"
    assert_no_selector "a", text: "Змінити оплату"
  end

  test "changing status assigns the mechanic in the same step" do
    order = Order.create!(client: clients(:ivan), bike: bikes(:trek), accepted_by: @owner,
                          accepted_at: Time.current, status: :intake)
    sign_in @owner
    visit order_path(order)

    find("a[title='Змінити статус']").click
    choose I18n.t("statuses.order.in_progress")
    select users(:andrii).name, from: "mechanic_id"
    find("input[type=submit][value='Зберегти статус']").trigger("click")

    assert_text "Статус оновлено."
    assert_equal users(:andrii), order.reload.mechanic
    assert order.in_progress?
  end

  test "selling from stock takes it off the shelf" do
    part = Part.create!(name: "Камера 700", category: Category.part.active.first,
                        base_price: 180, purchase_price: 100)
    StockMovement.create!(part: part, kind: :receipt, quantity: 5, user: @owner)
    @owner.update!(sales_percent: 10)
    sign_in @owner

    visit root_path
    click_on "+ Новий продаж"
    within("[data-controller='sale-items']") do
      pick "Камера 700 — 180 грн (5 шт)", from: "select[name*='part_id']"
      fill_in find("input[name*='quantity']")[:name], with: "2"
    end
    find("input[type=submit][value='Записати продаж']").trigger("click")

    assert_text "Продаж записано."
    assert_text "360 грн"
    assert_equal 3, part.reload.stock_quantity
  end

  # Not everything at the counter is in the catalogue.
  test "selling a one-off position that is not in stock" do
    part = Part.create!(name: "Камера 700", category: Category.part.active.first, base_price: 180)
    StockMovement.create!(part: part, kind: :receipt, quantity: 5, user: @owner)
    sign_in @owner

    visit root_path
    click_on "+ Новий продаж"

    # First line: a one-off, leaving the catalogue select blank.
    within all("[data-sale-items-target='rows'] > div").first do
      fill_in find("input[name*='[name]']")[:name], with: "Підкачати колесо"
      fill_in find("input[name*='price']")[:name], with: "150"
    end

    # Second line: straight from the shelf.
    click_on "+ Ще позиція"
    within all("[data-sale-items-target='rows'] > div").last do
      pick "Камера 700 — 180 грн (5 шт)", from: "select[name*='part_id']"
    end

    find("input[type=submit][value='Записати продаж']").trigger("click")
    assert_text "Продаж записано."
    assert_text "330 грн"                    # 150 one-off + 180 from stock
    assert_text "Підкачати колесо"
    assert_equal 4, part.reload.stock_quantity, "only the catalogue line moves stock"
  end

  test "issuing a rental marks the bike as out and bills the nights" do
    RentalBike.create!(name: "Trek прокат", daily_rate: 300)
    sign_in @owner

    visit rentals_path
    assert_text "Доступний"

    click_on "+ Видати в прокат"
    pick "Trek прокат — 300 грн/доба", from: "#rental_rental_bike_ids"
    fill_in "rental[renter_name]", with: "Гість"
    fill_in "rental[rented_from]", with: Date.current.beginning_of_month.iso8601
    fill_in "rental[rented_to]", with: (Date.current.beginning_of_month + 2).iso8601
    find("input[type=submit][value='Видати']").trigger("click")

    assert_text "Велосипед видано в прокат."
    assert_text "У прокаті"
    assert_text "600 грн"   # 2 доби × 300

    click_on "Повернути"
    assert_text "Велосипед повернуто."
    assert_text "Доступний"
  end

  # D67: two bikes in one handover, to a client whose passport is on file.
  test "issuing two bikes to a client whose documents are already on file" do
    RentalBike.create!(name: "Trek прокат", daily_rate: 300)
    RentalBike.create!(name: "Merida прокат", daily_rate: 350)
    clients(:ivan).documents.attach(io: file_fixture("test_photo.png").open, filename: "passport.png", content_type: "image/png")
    sign_in @owner

    visit rentals_path
    click_on "+ Видати в прокат"
    pick "Trek прокат — 300 грн/доба", from: "#rental_rental_bike_ids"
    pick "Merida прокат — 350 грн/доба", from: "#rental_rental_bike_ids"
    pick clients(:ivan).name, from: "#rental_client_id", search: "Петренко"
    assert_text "Документи вже є в картці клієнта"

    fill_in "rental[rented_from]", with: Date.current.beginning_of_month.iso8601
    fill_in "rental[rented_to]", with: (Date.current.beginning_of_month + 1).iso8601
    find("input[type=submit][value='Видати']").trigger("click")

    assert_text "Видано в прокат: 2 велосипеди."
    assert_equal [ clients(:ivan) ], Rental.all.map(&:client).uniq
    assert_equal [ 300, 350 ], Rental.all.map { |rental| rental.amount.to_i }.sort
  end

  test "a rental can be issued straight from the board" do
    RentalBike.create!(name: "Trek прокат", daily_rate: 300)
    sign_in @owner

    visit root_path
    click_on "+ Новий прокат"

    pick "Trek прокат — 300 грн/доба", from: "#rental_rental_bike_ids"
    fill_in "rental[renter_name]", with: "Гість"
    fill_in "rental[rented_from]", with: Date.current.beginning_of_month.iso8601
    fill_in "rental[rented_to]", with: (Date.current.beginning_of_month + 2).iso8601
    find("input[type=submit][value='Видати']").trigger("click")

    assert_text "Велосипед видано в прокат."
    assert_text "600 грн"
    assert_equal 1, Rental.count
  end

  # Opening this from the board makes an empty fleet a likely first encounter.
  test "an empty fleet says so instead of claiming everything is out" do
    sign_in @owner
    visit root_path
    click_on "+ Новий прокат"

    assert_text "Парк прокату порожній"
    assert_no_text "Усі велосипеди зараз у прокаті"
  end

  test "the announcement ticker appears once the owner writes one" do
    sign_in @owner

    visit edit_announcement_path
    fill_in "announcement[text]", with: "У суботу до 15:00"
    click_on I18n.t("actions.save")

    assert_text "Оголошення збережено."
    visit root_path
    assert_selector ".led-ticker", text: "У суботу до 15:00"
  end
  # D61: the slot picker is JavaScript — changing the type re-fetches the free
  # times — so the whole booking path is worth one run in a real browser.
  test "booking a slot from the calendar, then the client arriving" do
    WorkingHour.week.each(&:save!)
    MaintenanceType.create!(name: "Базове ТО", duration_minutes: 60)
    MaintenanceType.create!(name: "Повне ТО", duration_minutes: 120)
    date = (Date.current + 1..Date.current + 7).find { |d| Bookings::Day.new(d).open? }
    sign_in @owner

    visit new_booking_path(date: date)
    fill_in "client_search", with: clients(:ivan).name.split.first
    click_on clients(:ivan).name
    fill_in "bike_name", with: "Trek Marlin"

    select "Повне ТО (2 год)", from: "maintenance_type_id"
    assert_text "Повне ТО триває 2 год"
    find("label", text: "10:00").click
    fill_in "telegram_username", with: "@ivan_p"
    click_on "Записати"

    assert_text "Записано на #{date.strftime('%d.%m.%Y')} 10:00"
    assert_text "10:00–12:00"
    assert_selector "#upcoming_bookings a", text: "Повне ТО · Trek Marlin"

    within("#booking_day") { click_on "Повне ТО · Trek Marlin" }
    assert_text "@ivan_p"
    click_on "Клієнт приїхав"
    assert_text "Велосипед прийнято."
    assert_selector "span", text: "Нове"
  end

  # D64: the send button is a form inside the modal's <dialog>, so one browser
  # run is worth it — the Turbo round trip has to close it and report back.
  test "sending the ready message through the Telegram bot" do
    factory_was = Telegram::Notifier.api_factory
    api = FakeTelegramApi.new
    Telegram::Notifier.api_factory = -> { api }
    ENV["TELEGRAM_BOT_TOKEN"] = "123456:test-token"
    TelegramChat.create!(chat_id: 4242, client: clients(:ivan))
    order = Order.create!(client: clients(:ivan), bike: bikes(:trek), accepted_by: @owner,
                          accepted_at: Time.current, status: :waiting_pickup)
    sign_in @owner

    visit order_path(order)
    find("a[title='Повідомлення клієнту']").click
    find("button", text: "Надіслати в Telegram").trigger("click")

    assert_text "Повідомлення надіслано клієнту в Telegram."
    assert_no_selector "dialog[open]"
    assert_equal 4242, api.calls.last.last[:chat_id]
  ensure
    ENV.delete("TELEGRAM_BOT_TOKEN")
    Telegram::Notifier.api_factory = factory_was
  end
end
