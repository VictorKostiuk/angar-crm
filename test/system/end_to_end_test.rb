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
    fill_in "bike_name", with: "Trek Marlin"
    fill_in "problem", with: "Скрипить ланцюг"
    click_on "Прийняти велосипед"

    assert_text "Скрипить ланцюг"

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
      select "Камера 700 — 180 грн (5 шт)", from: find("select[name*='part_id']")[:name]
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
      select "Камера 700 — 180 грн (5 шт)", from: find("select[name*='part_id']")[:name]
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
    select "Trek прокат — 300 грн/доба", from: "rental[rental_bike_id]"
    fill_in "rental[renter_name]", with: "Гість"
    fill_in "rental[rented_from]", with: Date.current.to_s
    fill_in "rental[rented_to]", with: (Date.current + 2).to_s
    find("input[type=submit][value='Видати']").trigger("click")

    assert_text "Велосипед видано в прокат."
    assert_text "У прокаті"
    assert_text "600 грн"   # 2 доби × 300

    click_on "Повернути"
    assert_text "Велосипед повернуто."
    assert_text "Доступний"
  end

  test "a rental can be issued straight from the board" do
    RentalBike.create!(name: "Trek прокат", daily_rate: 300)
    sign_in @owner

    visit root_path
    click_on "+ Новий прокат"

    select "Trek прокат — 300 грн/доба", from: "rental[rental_bike_id]"
    fill_in "rental[renter_name]", with: "Гість"
    fill_in "rental[rented_from]", with: Date.current.to_s
    fill_in "rental[rented_to]", with: (Date.current + 2).to_s
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
end
