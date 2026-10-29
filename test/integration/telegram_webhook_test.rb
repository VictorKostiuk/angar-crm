require "test_helper"

# Telegram's way in (D62). No session, no CSRF token, no browser — just the
# secret Telegram was given with the webhook, echoed in a header.
class TelegramWebhookTest < ActionDispatch::IntegrationTest
  setup do
    ENV["TELEGRAM_BOT_TOKEN"] = "123456:test-token"
    @api = FakeTelegramApi.new
    @factory_was = Telegram::WebhooksController.bot_factory
    Telegram::WebhooksController.bot_factory = -> { Telegram::Bot.new(api: @api) }
  end

  teardown do
    ENV.delete("TELEGRAM_BOT_TOKEN")
    Telegram::WebhooksController.bot_factory = @factory_was
  end

  def update
    { update_id: 1, message: { message_id: 1, chat: { id: 55, type: "private" }, from: { id: 55, first_name: "Іван" }, text: "/start" } }
  end

  def deliver(secret: Telegram::Api.webhook_secret, body: update.to_json)
    post telegram_webhook_path, params: body,
         headers: { "Content-Type" => "application/json", "X-Telegram-Bot-Api-Secret-Token" => secret }
  end

  test "a delivery with the right secret reaches the bot" do
    deliver

    assert_response :ok
    assert_equal 1, @api.calls.count { |name, _| name == :send_message }
    assert TelegramChat.exists?(chat_id: 55)
  end

  test "the wrong secret is refused before anything is read" do
    deliver(secret: "nope")

    assert_response :forbidden
    assert_not TelegramChat.exists?(chat_id: 55)
  end

  test "without a token there is no endpoint" do
    ENV.delete("TELEGRAM_BOT_TOKEN")
    deliver(secret: "anything")

    assert_response :not_found
  end

  test "a failing update is answered 200 so Telegram does not redeliver it forever" do
    bot = Object.new
    def bot.handle(_update) = raise("boom")
    Telegram::WebhooksController.bot_factory = -> { bot }

    deliver

    assert_response :ok
  end

  test "a body that is not JSON is a bad request" do
    deliver(body: +"not json")

    assert_response :bad_request
  end
end
