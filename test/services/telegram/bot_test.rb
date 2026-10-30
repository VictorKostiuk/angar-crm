require "test_helper"

# D62: the booking conversation, driven the way a person drives it — texts,
# a shared contact, and taps on the buttons the bot showed last.
class Telegram::BotTest < ActiveSupport::TestCase
  MONDAY = Date.new(2026, 11, 2)
  CHAT = 4242

  setup do
    travel_to Time.zone.local(2026, 11, 1, 12, 0) # the Sunday before
    @api = FakeTelegramApi.new
    @bot = Telegram::Bot.new(api: @api)
    @update_id = 0
  end

  # Mon–Sat 10:00–19:00 by default; Monday shortened so its free times fit a
  # line. Two quick-pick problems, as Налаштування › Запис would have (D63).
  def schedule!
    WorkingHour.week.each(&:save!)
    WorkingHour.find_by!(weekday: 1).update!(closes_at: "13:00")
    @basic = MaintenanceType.create!(name: "Базове ТО", duration_minutes: 60)
    @brakes = BookingProblem.create!(name: "Гальма", position: 1)
    BookingProblem.create!(name: "Скрип або стук", position: 2)
  end

  # Signed up, with type, day, time and bike picked: the problem question is next.
  def up_to_problem!
    schedule!
    sign_up!
    press! "Записатися"
    press! "Базове ТО"
    press! "Пн 02.11"
    press! "10:00"
    press! bikes(:trek).display_name
  end

  def from = { "id" => CHAT, "first_name" => "Іван", "username" => "ivan_p" }
  def chat_data(type = "private") = { "id" => CHAT, "type" => type }

  def text!(text, chat_type: "private")
    @bot.handle("update_id" => (@update_id += 1),
                "message" => { "message_id" => @update_id, "chat" => chat_data(chat_type), "from" => from, "text" => text })
  end

  def contact!(phone, user_id: CHAT, first_name: "Іван", last_name: "Петренко")
    @bot.handle("update_id" => (@update_id += 1),
                "message" => { "message_id" => @update_id, "chat" => chat_data, "from" => from,
                               "contact" => { "phone_number" => phone, "first_name" => first_name,
                                              "last_name" => last_name, "user_id" => user_id } })
  end

  def tap!(data, message_id: 7)
    @bot.handle("update_id" => (@update_id += 1),
                "callback_query" => { "id" => "cb#{@update_id}", "from" => from, "data" => data,
                                      "message" => { "message_id" => message_id, "chat" => chat_data } })
  end

  # Taps the button whose label contains `label`, on the keyboard shown last.
  def press!(label)
    _text, data = @api.buttons.find { |text, _| text.include?(label) }
    assert data, "no button «#{label}» among #{@api.buttons.map(&:first)}"
    tap!(data)
  end

  def sign_up!
    text! "/start"
    contact! clients(:ivan).phone
  end

  def chat = TelegramChat.find_by!(chat_id: CHAT)
  def times_offered = @api.buttons.map(&:first).grep(/\A\d\d:\d\d\z/)

  def book!(client: clients(:ivan), bike: bikes(:trek), at: "2026-11-02 10:00", type: @basic)
    Order.create!(client: client, bike: bike, accepted_by: users(:owner), accepted_at: Time.current,
                  status: :booked, scheduled_at: Time.zone.parse(at), booking_minutes: 60, maintenance_type: type)
  end

  test "/start from an unknown chat asks for the phone with a contact button" do
    text! "/start"

    assert_nil chat.client
    assert_equal "phone", chat.step
    assert_equal true, @api.last_markup[:keyboard].flatten.first[:request_contact]
  end

  test "sharing a known phone links the chat to that client and keeps their Telegram nick" do
    sign_up!

    assert_equal clients(:ivan), chat.client
    assert_equal "ivan_p", clients(:ivan).reload.telegram_username
    assert_includes @api.texts, "Раді бачити, Іван!"
    assert_equal [ "📅 Записатися", "🗓 Мої записи" ], @api.buttons.map(&:first)
  end

  test "an unknown phone creates the client from the contact's name" do
    text! "/start"

    assert_difference -> { Client.count }, 1 do
      contact! "+380671112233", first_name: "Олена", last_name: "Коваль"
    end
    client = Client.find_by!(phone: "380671112233")
    assert_equal "Олена Коваль", client.name
    assert_equal client, chat.client
    assert_includes @api.texts, "Дякуємо, Олена! Тепер можна записатися."
  end

  test "a forwarded contact is not accepted as the person's own number" do
    text! "/start"
    contact! clients(:ivan).phone, user_id: 999

    assert_nil chat.client
    assert @api.last_markup[:keyboard], "asks for the phone again"
  end

  test "a number the client base cannot hold is refused" do
    text! "/start"

    assert_no_difference -> { Client.count } do
      contact! "+4915112345678"
    end
    assert_match "Не вдалося зберегти номер", @api.last_text
    assert_nil chat.client
  end

  test "the whole flow books a slot that then shows on the calendar" do
    schedule!
    sign_up!

    press! "Записатися"
    assert_equal "Оберіть, що потрібно:", @api.last_text
    press! "Базове ТО"
    assert_equal "Базове ТО — оберіть день:", @api.last_text
    press! "Пн 02.11"
    assert_equal %w[ 10:00 10:30 11:00 11:30 12:00 ], times_offered
    press! "10:00"
    press! bikes(:trek).display_name
    press! "Гальма"
    assert_match "Коли: Пн 02.11, 10:00–11:00", @api.last_text
    assert_match "Проблема: Гальма", @api.last_text

    assert_difference -> { Order.count }, 1 do
      press! "Підтвердити"
    end

    order = Order.order(:id).last
    assert order.booked?
    assert_equal [ clients(:ivan), bikes(:trek), @basic, 60, "Гальма", "telegram" ],
                 [ order.client, order.bike, order.maintenance_type, order.booking_minutes, order.problem, order.booking_channel ]
    assert_equal Time.zone.parse("2026-11-02 10:00"), order.scheduled_at
    assert order.accepted_by.telegram_bot?
    assert_match "Вас записано!", @api.last_text
    assert_match "Коли: Пн 02.11, 10:00–11:00", @api.last_text
    assert_equal [ order ], Bookings::Day.new(MONDAY).bookings.map(&:order), "it is on the calendar"
    assert_equal [ "menu", {} ], [ chat.step, chat.draft ]
  end

  test "a new bike and a problem in the client's own words" do
    schedule!
    sign_up!
    press! "Записатися"
    press! "Базове ТО"
    press! "Пн 02.11"
    press! "11:00"
    press! "Інший велосипед"
    text! "Cube Aim, синій"
    press! "Написати своє"
    text! "Скрипить каретка і злітає ланцюг"
    assert_match "Велосипед: Cube Aim, синій", @api.last_text
    press! "Підтвердити"

    order = Order.order(:id).last
    assert_equal "Cube Aim, синій", order.bike.name
    assert_equal clients(:ivan), order.bike.client
    assert_equal "Скрипить каретка і злітає ланцюг", order.problem
  end

  test "a slot taken between picking and confirming is refused and the other times offered" do
    schedule!
    sign_up!
    press! "Записатися"
    press! "Базове ТО"
    press! "Пн 02.11"
    press! "10:00"
    press! bikes(:trek).display_name
    press! "Пропустити"
    book!(at: "2026-11-02 10:00")

    assert_no_difference -> { Order.count } do
      press! "Підтвердити"
    end
    assert_includes @api.texts, "На жаль, цей час щойно зайняли."
    assert_equal %w[ 11:00 11:30 12:00 ], times_offered
  end

  test "«Мої записи» lists upcoming bookings and cancels one after confirmation" do
    schedule!
    sign_up!
    order = book!(at: "2026-11-02 10:00")

    press! "Мої записи"
    assert_match "Пн 02.11, 10:00–11:00 — Базове ТО", @api.last_text
    press! "Скасувати 02.11 10:00"
    assert_equal "Скасувати запис на Пн 02.11, 10:00–11:00?", @api.last_text
    press! "Так, скасувати"

    assert order.reload.cancelled?
    assert_equal "Скасовано клієнтом у Telegram", order.cancel_reason
    assert_includes Bookings::Day.new(MONDAY).free_starts(60).map { |t| t.strftime("%H:%M") }, "10:00", "the slot is free again"
  end

  test "someone else's booking cannot be cancelled by guessing its id" do
    schedule!
    sign_up!
    other = Client.create!(name: "Олена", phone: "380671112233")
    order = book!(client: other, bike: other.bikes.create!(name: "Cube"))

    tap! "cancel_yes:#{order.id}"

    assert order.reload.booked?
    assert_equal "Цей запис уже не активний.", @api.last_text
  end

  test "booking is unavailable until the week is saved and a type exists" do
    sign_up!
    press! "Записатися"

    assert_match "тимчасово недоступний", @api.last_text
    assert_equal [ "📅 Записатися", "🗓 Мої записи" ], @api.buttons.map(&:first)
  end

  test "/cancel abandons a half-made booking" do
    schedule!
    sign_up!
    press! "Записатися"
    press! "Базове ТО"
    text! "/cancel"

    assert_equal [ "menu", {} ], [ chat.step, chat.draft ]
    assert_includes @api.texts, "Запис не створено."
  end

  # Often a "Дякую!" to a notice the shop sent (D64) — nobody reads it, and
  # the bot says so instead of claiming not to understand.
  test "stray text at the menu says the bot does not read messages and re-shows the menu" do
    sign_up!
    text! "Дякую, буду о шостій"

    assert_match "не читаю повідомлень", @api.last_text
    assert_equal [ "📅 Записатися", "🗓 Мої записи" ], @api.buttons.map(&:first)
  end

  test "the quick-pick problems are the ones set up in the CRM, in their order" do
    up_to_problem!

    assert_equal [ "Гальма", "Скрип або стук", "✍️ Написати своє", "Пропустити" ], @api.buttons.map(&:first)
  end

  # The draft keeps the text that was tapped, so editing the list while a
  # client is mid-booking cannot change what they booked.
  test "the problem booked is the text tapped, even if the list is edited before confirming" do
    up_to_problem!
    press! "Гальма"
    @brakes.update!(name: "Гальма (дискові)")

    press! "Підтвердити"
    assert_equal "Гальма", Order.order(:id).last.problem
  end

  test "a button for a problem deleted since shows the current list again" do
    up_to_problem!
    @brakes.destroy!

    tap!("problem:#{@brakes.id}")
    assert_equal "problem", chat.step
    assert_equal [ "Скрип або стук", "✍️ Написати своє", "Пропустити" ], @api.buttons.map(&:first)
  end

  test "with no quick picks set up the bot asks for the client's own words" do
    schedule!
    BookingProblem.delete_all
    sign_up!
    press! "Записатися"
    press! "Базове ТО"
    press! "Пн 02.11"
    press! "10:00"
    press! bikes(:trek).display_name

    assert_equal "Що турбує? Напишіть своїми словами або пропустіть.", @api.last_text
    assert_equal [ "✍️ Написати своє", "Пропустити" ], @api.buttons.map(&:first)
  end

  # The button on the shop's «запис скасовано» notice (D64): the notice has to
  # stay readable, so booking starts in a message of its own.
  test "booking again from a cancellation notice leaves the notice as it was" do
    schedule!
    sign_up!
    @api.calls.clear

    tap!("notice:book", message_id: 99)

    assert_equal "type", chat.step
    assert_equal "Оберіть, що потрібно:", @api.last_text
    assert_not @api.calls.any? { |name, args| name == :edit_message_text && args[:message_id] == 99 }
    assert @api.calls.any? { |name, _| name == :send_message }
  end

  test "the same update delivered twice is handled once" do
    update = { "update_id" => 50, "message" => { "message_id" => 1, "chat" => chat_data, "from" => from, "text" => "/start" } }

    @bot.handle(update)
    @bot.handle(update)

    assert_equal 1, @api.calls.count { |name, _| name == :send_message }
  end

  test "group chats are ignored" do
    text! "/start", chat_type: "group"

    assert_empty @api.calls
    assert_nil TelegramChat.find_by(chat_id: CHAT)
  end

  test "a tap edits the message its keyboard was on; a typed reply gets a new one" do
    schedule!
    sign_up!

    tap! "menu:book", message_id: 7
    name, args = @api.calls.last
    assert_equal [ :edit_message_text, 7 ], [ name, args[:message_id] ]

    text! "/start"
    assert_equal :send_message, @api.calls.last.first
  end

  test "a keyboard tapped before the phone was shared just asks for the phone" do
    text! "/start"
    tap! "menu:book"

    assert @api.last_markup[:keyboard].flatten.first[:request_contact]
  end
end
