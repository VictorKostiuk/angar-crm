require "test_helper"

# D64: what the shop sends a client through the bot, and how a refusal from
# Telegram comes back as something a person at the counter can act on.
class Telegram::NotifierTest < ActiveSupport::TestCase
  setup do
    ENV["TELEGRAM_BOT_TOKEN"] = "123456:test-token"
    @api = FakeTelegramApi.new
    @factory_was = Telegram::Notifier.api_factory
    Telegram::Notifier.api_factory = -> { @api }

    travel_to Time.zone.local(2026, 11, 1, 12, 0)
    WorkingHour.week.each(&:save!)
    @client = clients(:ivan)
    TelegramChat.create!(chat_id: 4242, client: @client)
    @order = Order.create!(client: @client, bike: bikes(:trek), accepted_by: users(:owner), accepted_at: Time.current,
                           status: :booked, scheduled_at: Time.zone.local(2026, 11, 2, 10), booking_minutes: 60,
                           maintenance_type: MaintenanceType.create!(name: "Базове ТО", duration_minutes: 60))
  end

  teardown do
    ENV.delete("TELEGRAM_BOT_TOKEN")
    Telegram::Notifier.api_factory = @factory_was
  end

  test "the ready message goes to the client's chat as plain text" do
    result = Telegram::Notifier.new.ready(@order, "Ваш велосипед «Trek_X *Pro*» готовий")

    assert result.sent?
    name, args = @api.calls.last
    assert_equal :send_message, name
    assert_equal 4242, args[:chat_id]
    assert_equal "Ваш велосипед «Trek_X *Pro*» готовий", args[:text]
    assert_not args.key?(:parse_mode)
  end

  test "a cancelled booking names the slot and offers to book again" do
    assert Telegram::Notifier.new.booking_cancelled(@order).sent?

    assert_match "ваш запис на Пн 02.11, 10:00–11:00 (Базове ТО) скасовано", @api.last_text
    assert_equal [ [ "📅 Записатися", "notice:book" ] ], @api.buttons
  end

  test "a client who blocked the bot is reported as such" do
    @api.failure = Telegram::Api::Error.new("sendMessage: Forbidden: bot was blocked by the user", code: 403)

    result = Telegram::Notifier.new.ready(@order, "Готово")
    assert_not result.sent?
    assert_equal "клієнт заблокував бота", result.error
  end

  test "Telegram not answering is reported, not raised" do
    @api.failure = Net::OpenTimeout.new

    result = Telegram::Notifier.new.ready(@order, "Готово")
    assert_equal "Telegram не відповідає, спробуйте пізніше", result.error
  end

  test "a client without a chat gets nothing sent" do
    @client.telegram_chat.destroy!

    result = Telegram::Notifier.new.ready(@order.reload, "Готово")
    assert_equal "клієнт не підключений до бота", result.error
    assert_empty @api.calls
  end

  test "it is only available with a token and a linked chat" do
    assert Telegram::Notifier.available_for?(@client)
    assert_not Telegram::Notifier.available_for?(Client.create!(name: "Олена Коваль", phone: "380671112233"))

    ENV.delete("TELEGRAM_BOT_TOKEN")
    assert_not Telegram::Notifier.available_for?(@client)
  end
end
