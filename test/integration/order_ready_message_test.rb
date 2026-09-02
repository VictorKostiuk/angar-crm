require "test_helper"

class OrderReadyMessageTest < ActionDispatch::IntegrationTest
  setup do
    @owner = users(:owner)
    @order = Order.create!(client: clients(:ivan), bike: bikes(:trek), accepted_by: @owner,
                           mechanic: users(:andrii), accepted_at: Time.current, status: :waiting_pickup)

    post session_path, params: { email_address: @owner.email_address, password: "password123" }
  end

  # The textarea is the deliverable — everything the mechanic pastes into a
  # messenger comes out of it verbatim, so assert the whole body, not fragments.
  def message_body
    get order_ready_message_path(@order)
    assert_response :success

    CGI.unescapeHTML(response.body[%r{<textarea[^>]*>(.*?)</textarea>}m, 1])
  end

  test "the message prices every line and names the bike, the discount and the total" do
    @order.order_works.create!(name: "Заміна ланцюга", quantity: 1, price: 500)
    @order.order_works.create!(name: "Регулювання гальм", quantity: 1, price: 250)
    @order.order_parts.create!(name: "Ланцюг Shimano", quantity: 1, price: 950)
    @order.order_parts.create!(name: "Гальмівні колодки", quantity: 2, price: 150)
    @order.update!(discount_record: Discount.create!(name: "Промо", kind: :fixed_amount, value: 300))

    assert_equal <<~TEXT.strip, message_body
      Добрий день, Іван!

      Ваш велосипед «#{@order.bike.name}» готовий до видачі.

      Виконані роботи:
      - Заміна ланцюга — 500 грн
      - Регулювання гальм — 250 грн

      Використані матеріали:
      - Ланцюг Shimano — 950 грн
      - Гальмівні колодки × 2 — 300 грн

      Знижка: −300 грн
      До сплати: 1 700 грн

      Чекаємо вас у майстерні!
    TEXT
  end

  # An order with no parts must not print a dangling materials header, and an
  # order with no discount must not print "Знижка: −0 грн" — the two cases a
  # single interpolated template would have got wrong. A quantity of 1 also
  # drops its "× 1", which is noise on the lines most orders are made of.
  test "empty sections drop out instead of leaving an empty header" do
    @order.order_works.create!(name: "Заміна ланцюга", quantity: 1, price: 500)

    assert_equal <<~TEXT.strip, message_body
      Добрий день, Іван!

      Ваш велосипед «#{@order.bike.name}» готовий до видачі.

      Виконані роботи:
      - Заміна ланцюга — 500 грн

      До сплати: 500 грн

      Чекаємо вас у майстерні!
    TEXT
  end

  # A fractional quantity is legal on a work line (numeric(8,2)) — half an hour
  # of labour has to read as "× 0,5", not as a rounded-off "1".
  test "a fractional quantity keeps its decimals" do
    @order.order_works.create!(name: "Діагностика", quantity: 0.5, price: 400)

    assert_includes message_body, "- Діагностика × 0,5 — 200 грн"
  end

  # Reachable: a mechanic can move an order to «Очікує видачі» before entering
  # any lines. The message stays coherent — greeting, bike, total, closing —
  # rather than printing two headers with nothing under them.
  test "an order with no lines at all still reads as a message" do
    assert_equal <<~TEXT.strip, message_body
      Добрий день, Іван!

      Ваш велосипед «#{@order.bike.name}» готовий до видачі.

      До сплати: 0 грн

      Чекаємо вас у майстерні!
    TEXT
  end

  test "the order page offers the message only while the bike is waiting to be picked up" do
    get order_path(@order)
    assert_select "a[href=?]", order_ready_message_path(@order)

    @order.update!(status: :in_progress)
    get order_path(@order)
    assert_select "a[href=?]", order_ready_message_path(@order), false,
      "an order still in the workshop is not ready for pickup"

    @order.update!(status: :closed)
    get order_path(@order)
    assert_select "a[href=?]", order_ready_message_path(@order), false,
      "a closed order has already been handed over"
  end

  # The button lives in #order_header, which orders/refresh re-renders — so
  # moving the order to «Очікує видачі» from the status modal has to reveal it
  # without a reload.
  test "changing the status to waiting pickup streams the message button in" do
    @order.update!(status: :in_progress)

    patch order_status_path(@order), params: { status: "waiting_pickup" },
          headers: { "Accept" => "#{Mime[:turbo_stream]}, text/html" }

    assert_response :success
    assert_select "turbo-stream[action=update][target=order_header] template",
      html: %r{#{Regexp.escape(order_ready_message_path(@order))}}
  end
end
