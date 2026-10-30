require "test_helper"

# D64: the shop telling a client something through the bot — the bike is
# ready, or their booking is off. Both are a button a person presses, and both
# report back whether the message actually went.
class TelegramNoticesTest < ActionDispatch::IntegrationTest
  setup do
    travel_to Time.zone.local(2026, 11, 1, 12, 0)
    ENV["TELEGRAM_BOT_TOKEN"] = "123456:test-token"
    @api = FakeTelegramApi.new
    @factory_was = Telegram::Notifier.api_factory
    Telegram::Notifier.api_factory = -> { @api }

    @owner = users(:owner)
    @client = clients(:ivan)
    TelegramChat.create!(chat_id: 4242, client: @client)
    post session_path, params: { email_address: @owner.email_address, password: "password123" }
  end

  teardown do
    ENV.delete("TELEGRAM_BOT_TOKEN")
    Telegram::Notifier.api_factory = @factory_was
  end

  def turbo_headers
    { "Accept" => "#{Mime[:turbo_stream]}, text/html, application/xhtml+xml" }
  end

  def ready_order
    Order.create!(client: @client, bike: bikes(:trek), accepted_by: @owner, mechanic: users(:andrii),
                  accepted_at: Time.current, status: :waiting_pickup)
  end

  def booking
    WorkingHour.week.each(&:save!)
    Order.create!(client: @client, bike: bikes(:trek), accepted_by: @owner, accepted_at: Time.current,
                  status: :booked, scheduled_at: Time.zone.local(2026, 11, 2, 10), booking_minutes: 60,
                  maintenance_type: MaintenanceType.create!(name: "Базове ТО", duration_minutes: 60))
  end

  # --- ready for pickup ------------------------------------------------------

  test "the ready message offers the bot for a client who uses it, and sends exactly what it shows" do
    order = ready_order
    order.order_works.create!(name: "Заміна ланцюга", quantity: 1, price: 500)

    get order_ready_message_path(order)
    assert_select "form[action=?] button", order_ready_message_path(order), text: "Надіслати в Telegram"
    shown = CGI.unescapeHTML(response.body[%r{<textarea[^>]*>(.*?)</textarea>}m, 1])

    post order_ready_message_path(order), headers: turbo_headers

    assert_response :success
    assert_equal Mime[:turbo_stream], response.media_type
    assert_select "turbo-stream[action=update][target=flash] template", text: /надіслано клієнту в Telegram/
    assert_equal [ 4242, shown ], @api.calls.last.last.values_at(:chat_id, :text)
    assert_not_nil order.reload.ready_notified_at

    get order_ready_message_path(order)
    assert_select "button", text: "Надіслати ще раз"
    assert_match "Надіслано в Telegram 01.11 о 12:00", response.body
  end

  test "without the bot the ready message says why there is no send button" do
    @client.telegram_chat.destroy!
    order = ready_order

    get order_ready_message_path(order)
    assert_select "button", text: "Надіслати в Telegram", count: 0
    assert_match "Клієнт ще не підключив Telegram-бот", response.body

    ENV.delete("TELEGRAM_BOT_TOKEN")
    get order_ready_message_path(order)
    assert_no_match "Telegram-бот", response.body, "no bot, nothing to explain"
  end

  test "a refused message is shown in the modal and not recorded as sent" do
    order = ready_order
    @api.failure = Telegram::Api::Error.new("sendMessage: Forbidden: bot was blocked by the user", code: 403)

    post order_ready_message_path(order), headers: turbo_headers

    assert_response :unprocessable_entity
    assert_match "Не надіслано: клієнт заблокував бота", response.body
    assert_nil order.reload.ready_notified_at
  end

  test "an order that is not ready is not announced as ready" do
    order = ready_order
    order.update!(status: :in_progress)

    post order_ready_message_path(order), headers: turbo_headers

    assert_response :unprocessable_entity
    assert_empty @api.calls
  end

  # --- a booking cancelled by the shop --------------------------------------

  test "cancelling a booking tells the client by default" do
    order = booking

    get edit_order_cancellation_path(order)
    assert_select "input[type=checkbox][name=notify_telegram][checked]"

    patch order_cancellation_path(order), params: { reason: "Майстер захворів", notify_telegram: "1" }, headers: turbo_headers

    assert order.reload.cancelled?
    assert_match "запис на Пн 02.11, 10:00–11:00 (Базове ТО) скасовано", @api.last_text
    assert_no_match "Майстер захворів", @api.last_text, "the reason is the shop's own note"
    assert_select "turbo-stream[action=update][target=flash] template", text: /Клієнту надіслано повідомлення в Telegram/
  end

  test "unticking the box cancels without a message" do
    order = booking

    patch order_cancellation_path(order), params: { reason: "Дубль", notify_telegram: "0" }, headers: turbo_headers

    assert order.reload.cancelled?
    assert_empty @api.calls
  end

  test "a failed message still cancels the booking and says so" do
    order = booking
    @api.failure = Net::ReadTimeout.new

    patch order_cancellation_path(order), params: { reason: "Майстер захворів", notify_telegram: "1" }, headers: turbo_headers

    assert order.reload.cancelled?
    assert_select "turbo-stream[action=update][target=flash] template", text: /Повідомлення в Telegram не надіслано: Telegram не відповідає/
  end

  test "an order already in the workshop is cancelled without any Telegram option" do
    order = ready_order

    get edit_order_cancellation_path(order)
    assert_select "input[name=notify_telegram]", count: 0

    patch order_cancellation_path(order), params: { reason: "Клієнт передумав", notify_telegram: "1" }, headers: turbo_headers
    assert order.reload.cancelled?
    assert_empty @api.calls
  end

  test "the box survives a cancellation sent without a reason" do
    order = booking

    patch order_cancellation_path(order), params: { notify_telegram: "0" }, headers: turbo_headers

    assert_response :unprocessable_entity
    assert_select "input[type=checkbox][name=notify_telegram]"
    assert_select "input[type=checkbox][name=notify_telegram][checked]", count: 0
    assert_select "h2", text: "Скасувати запис"
  end
end
