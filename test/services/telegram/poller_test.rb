require "test_helper"

class Telegram::PollerTest < ActiveSupport::TestCase
  def start_update(id, chat: 1)
    { "update_id" => id, "message" => { "message_id" => id, "chat" => { "id" => chat, "type" => "private" },
                                        "from" => { "id" => chat, "first_name" => "A" }, "text" => "/start" } }
  end

  test "each update is handled and the next poll asks from past the last one" do
    api = FakeTelegramApi.new(updates: [ [ start_update(10), start_update(11) ], [] ])
    poller = Telegram::Poller.new(api: api, logger: Logger.new(nil))

    poller.run(once: true)
    poller.run(once: true)

    offsets = api.calls.select { |name, _| name == :get_updates }.map { |_, args| args[:offset] }
    assert_equal [ nil, 12 ], offsets
    assert_equal 2, api.calls.count { |name, _| name == :send_message }
  end

  test "one failing update does not stop the rest of its batch" do
    bot = Object.new
    def bot.handled = @handled ||= []
    def bot.handle(update)
      raise "boom" if update["update_id"] == 2

      handled << update["update_id"]
    end
    api = FakeTelegramApi.new(updates: [ [ { "update_id" => 1 }, { "update_id" => 2 }, { "update_id" => 3 } ] ])
    log = StringIO.new

    Telegram::Poller.new(api: api, bot: bot, logger: Logger.new(log)).run(once: true)

    assert_equal [ 1, 3 ], bot.handled
    assert_match "update 2 failed: RuntimeError: boom", log.string
  end

  test "a network failure is logged and polling goes on" do
    api = FakeTelegramApi.new
    def api.get_updates(**) = raise(SocketError, "getaddrinfo")
    log = StringIO.new

    Telegram::Poller.new(api: api, logger: Logger.new(log), retry_wait: 0).run(once: true)

    assert_match "polling failed (SocketError: getaddrinfo)", log.string
  end
end
