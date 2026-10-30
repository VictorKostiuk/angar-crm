require "application_system_test_case"

# A 9-column orders table was ~770px wide inside a 340px column, clipped by an
# overflow-hidden wrapper with no way to scroll. These lock in that nothing on
# any screen is wider than the screen — at phone width, where it bites.
class ResponsiveSystemTest < ApplicationSystemTestCase
  PHONE = [ 390, 844 ].freeze
  driven_by :cuprite, screen_size: PHONE

  setup do
    # Cuprite reuses the browser across tests, so a resize in one leaks into the
    # next — pin the width every time rather than restoring it afterwards.
    resize_to(*PHONE)
    @owner = users(:owner)
    @order = Order.create!(client: clients(:ivan), bike: bikes(:trek), accepted_by: @owner,
                           accepted_at: Time.current, status: :in_progress, mechanic: users(:andrii))
    @order.order_works.create!(name: "Заміна ланцюга", quantity: 1, price: 250)
    @order.order_parts.create!(name: "Ланцюг КМС X10", quantity: 1, price: 950)
    Part.create!(name: "Камера 700x35", category: Category.part.active.first, base_price: 180)
    RentalBike.create!(name: "Trek прокат", daily_rate: 300)
    # A booked day on the calendar, so the grid's busiest cell is measured too.
    WorkingHour.week.each(&:save!)
    type = MaintenanceType.create!(name: "Повне ТО з мийкою", duration_minutes: 120)
    start = Bookings::Day.new(Date.current + 1).free_starts(120).first
    Order.create!(client: clients(:ivan), bike: bikes(:trek), accepted_by: @owner, accepted_at: Time.current,
                  status: :booked, scheduled_at: start, booking_minutes: 120, maintenance_type: type) if start
  end

  # Elements that scroll horizontally on purpose are not overflow bugs, and
  # neither is text cut short with an ellipsis (Tailwind's `truncate`).
  OVERFLOW_JS = <<~JS
    (() => [...document.querySelectorAll('main, main *')]
      .filter(e => e.scrollWidth > e.clientWidth + 2 && e.clientWidth > 0)
      .filter(e => !['auto','scroll'].includes(getComputedStyle(e).overflowX))
      .filter(e => getComputedStyle(e).textOverflow !== 'ellipsis')
      .map(e => e.tagName.toLowerCase() + (e.id ? '#'+e.id : '') + ' ' + e.scrollWidth + '>' + e.clientWidth))()
  JS

  # resize_window returns before the viewport has actually changed, so the media
  # query can still be evaluating when the next assertion runs.
  def resize_to(width, height)
    page.driver.resize_window(width, height)
    Timeout.timeout(5) { sleep 0.05 until page.evaluate_script("window.innerWidth") == width }
  end

  def assert_fits(label)
    assert_equal [], page.evaluate_script(OVERFLOW_JS), "#{label} overflows its column on a phone"
    assert_equal 0, page.evaluate_script("document.documentElement.scrollWidth - document.documentElement.clientWidth"),
                 "#{label} makes the whole page scroll sideways"
  end

  test "no page overflows at phone width" do
    sign_in @owner

    { "Майстерня" => root_path, "Замовлення" => orders_path, "Замовлення #" => order_path(@order),
      "Клієнти" => clients_path, "Клієнт" => client_path(clients(:ivan)), "Велосипеди" => bikes_path,
      "Запчастини" => parts_path, "Послуги" => services_path, "Продажі" => sales_path,
      "Прокат" => rentals_path, "Склад" => stock_path, "Фінанси" => finances_path,
      "Механіки" => mechanics_path, "Налаштування" => users_path,
      "Записи" => bookings_path, "Новий запис" => new_booking_path,
      "Налаштування запису" => booking_settings_path, "Пошук" => search_path(q: "trek"),
      "Велосипед" => bike_path(bikes(:trek)) }.each do |label, path|
      visit path
      assert_fits label
    end
  end

  # Three action buttons now share the board header.
  test "the board header wraps its buttons instead of overflowing" do
    sign_in @owner
    visit root_path

    [ "+ Новий прокат", "+ Новий продаж", "+ Нове замовлення" ].each { |b| assert_link b }
    assert_fits "Майстерня"
  end

  test "no modal overflows at phone width" do
    sign_in @owner

    [ [ "Додати запчастину", -> { visit order_path(@order); click_on "+ Додати запчастину" } ],
      [ "Змінити статус",    -> { visit order_path(@order); find("a[title='Змінити статус']").click } ],
      [ "Оплата",            -> { visit order_path(@order); click_on "Оплата" } ],
      [ "Новий продаж",      -> { visit root_path; click_on "+ Новий продаж" } ],
      [ "Видати в прокат",   -> { visit rentals_path; click_on "+ Видати в прокат" } ] ].each do |label, open|
      open.call
      assert_selector "dialog[open]"

      dialog = page.evaluate_script(<<~JS)
        (() => { const d = document.querySelector('dialog[open]'), r = d.getBoundingClientRect();
          return { w: Math.round(r.width), vw: window.innerWidth, top: Math.round(r.top),
            over: [...d.querySelectorAll('*')]
              .filter(e => e.scrollWidth > e.clientWidth + 2 && e.clientWidth > 0)
              .filter(e => !['auto','scroll'].includes(getComputedStyle(e).overflowX))
              .map(e => e.tagName.toLowerCase() + ' ' + e.scrollWidth + '>' + e.clientWidth) }; })()
      JS

      assert_operator dialog["w"], :<=, dialog["vw"], "#{label} is wider than the screen"
      assert_operator dialog["top"], :>=, 0, "#{label} is cut off at the top"
      assert_equal [], dialog["over"], "#{label} has content wider than the dialog"
    end
  end

  # D70: below sm each row is a compact card — title and status on top, details
  # in a line — not a screen of "label … value" rows per record, and tapping
  # anywhere on it opens the record.
  test "list rows become compact, tappable cards on a phone" do
    sign_in @owner
    visit orders_path

    assert_selector "table.data-table"
    layout = page.evaluate_script(<<~JS)
      (() => { const tr = document.querySelector('.data-table tbody tr'),
                 meta = tr.querySelector('td[data-card=meta]'),
                 chevron = tr.querySelector('td[data-card=hide]'),
                 box = tr.getBoundingClientRect(),
                 corner = document.elementFromPoint(box.left + 4, box.bottom - 4);
        return { display: getComputedStyle(tr).display,
                 label: getComputedStyle(meta, '::before').content,
                 chevron: getComputedStyle(chevron).display,
                 height: Math.round(box.height),
                 tap: corner && corner.closest('a') && corner.closest('a').getAttribute('href'),
                 own: tr.querySelector('.card-link').getAttribute('href') }; })()
    JS
    assert_equal "flex", layout["display"], "a row is laid out as a card on a phone"
    assert_match "Механік", layout["label"], "a detail still says what it is"
    assert_equal "none", layout["chevron"], "the card itself replaces the chevron"
    assert_operator layout["height"], :<, 200, "one order is a list item, not a screen of label/value lines"
    assert_equal layout["own"], layout["tap"], "an empty corner of the card opens its order"
  end

  test "the orders filter folds behind a button on a phone" do
    sign_in @owner
    visit orders_path

    assert_no_selector "select[name=status]"
    click_on "Фільтри"
    assert_selector "select[name=status]"
  end

  test "the same tables are ordinary tables on a tablet" do
    resize_to(1024, 768)
    sign_in @owner
    visit orders_path

    assert_equal "table-cell", page.evaluate_script(
      "getComputedStyle(document.querySelector('.data-table tbody td')).display")
    assert_fits "Замовлення (tablet)"
  end
end
