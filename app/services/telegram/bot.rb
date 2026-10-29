module Telegram
  # The booking conversation: one update in, replies out through the API.
  #
  # Transport-agnostic — the webhook controller and the poller both hand
  # updates here, and tests hand in plain hashes with a fake API. Everything
  # between two messages lives on the TelegramChat row (step + draft), never in
  # this object, so a restart or a second web process picks up mid-booking.
  #
  # Buttons carry their whole meaning in callback_data ("date:2026-11-02"), so
  # a tap on an old keyboard still does something sensible instead of
  # depending on which step the chat happens to be in. Only typed text is
  # step-dependent (the bike's name, a problem in the client's own words).
  #
  # Availability is Bookings::Day, the same code the calendar uses, and the
  # booking itself goes through Orders::Create with its slot check and lock —
  # the bot cannot offer or take a time the calendar would refuse.
  class Bot
    include Wording

    DAYS_AHEAD = 30
    MAX_DATES = 12
    BIKE_NAME_LIMIT = 120
    PROBLEM_LIMIT = 500

    def initialize(api: Api.new)
      @api = api
    end

    def handle(update)
      update = update.deep_stringify_keys

      if (message = update["message"])
        with_chat(message["chat"], message["from"], update["update_id"]) { |chat| handle_message(chat, message) }
      elsif (query = update["callback_query"]) && query["message"]
        acknowledge(query["id"])
        with_chat(query["message"]["chat"], query["from"], update["update_id"]) { |chat| handle_callback(chat, query) }
      end
    end

    private
      # Private chats only — the bot has nothing to say in a group. Each update
      # id is processed once: Telegram re-delivers anything it did not see
      # confirmed, and a double-tap must not book twice.
      def with_chat(chat_data, from, update_id)
        return unless chat_data && chat_data["type"] == "private"

        chat = TelegramChat.find_or_initialize_by(chat_id: chat_data["id"])
        return if update_id && chat.last_update_id && update_id <= chat.last_update_id

        chat.assign_attributes(username: from&.dig("username"), first_name: from&.dig("first_name"), last_update_id: update_id)
        chat.save!
        yield chat
      end

      def acknowledge(query_id)
        @api.answer_callback_query(query_id)
      rescue Api::Error
        # Too old to acknowledge — the tap itself is still worth handling.
      end

      # --- messages -----------------------------------------------------------

      def handle_message(chat, message)
        return link_contact(chat, message) if message["contact"]

        text = message["text"].to_s.strip
        case text
        when "/start"
          chat.linked? ? menu(chat, t("linked_known", name: chat.client.first_name)) : ask_phone(chat)
        when "/cancel"
          chat.linked? ? menu(chat, t("cancelled_draft")) : ask_phone(chat)
        else
          return ask_phone(chat) unless chat.linked?

          case chat.step
          when "bike_name"
            chat.remember(bike_name: text.first(BIKE_NAME_LIMIT), bike_id: nil)
            ask_problem(chat)
          when "problem_text"
            chat.remember(problem: text.first(PROBLEM_LIMIT))
            show_confirm(chat)
          else
            menu(chat, t("unknown"))
          end
        end
      end

      def ask_phone(chat)
        chat.reset!(step: "phone")
        keyboard = { keyboard: [ [ { text: t("share_phone_button"), request_contact: true } ] ],
                     resize_keyboard: true, one_time_keyboard: true }
        @api.send_message(chat_id: chat.chat_id, text: t("share_phone"), reply_markup: keyboard)
      end

      # The contact button sends the person's own number, which is the only
      # one accepted — a forwarded contact would let anyone book as anyone.
      def link_contact(chat, message)
        contact = message["contact"]
        from = message["from"] || {}
        return ask_phone(chat) unless contact["user_id"] == from["id"]

        phone = Client.normalize_phone(contact["phone_number"])
        client = Client.find_by(phone: phone)
        new_client = client.nil?
        client ||= Client.new(name: contact_name(contact, from), phone: phone)
        client.telegram_username = from["username"] if client.telegram_username.blank? && from["username"].present?

        unless client.save
          @api.send_message(chat_id: chat.chat_id, text: t("phone_invalid", errors: client.errors.full_messages.to_sentence),
                            reply_markup: { remove_keyboard: true })
          return
        end

        chat.update!(client: client)
        @api.send_message(chat_id: chat.chat_id, text: t(new_client ? "linked_new" : "linked_known", name: client.first_name),
                          reply_markup: { remove_keyboard: true })
        menu(chat)
      end

      def contact_name(contact, from)
        [ contact["first_name"], contact["last_name"] ].compact_blank.join(" ").presence ||
          from["first_name"].presence || t("fallback_name")
      end

      # --- buttons --------------------------------------------------------------

      def handle_callback(chat, query)
        return ask_phone(chat) unless chat.linked?

        edit = query["message"]["message_id"]
        action, arg = query["data"].to_s.split(":", 2)

        case action
        when "menu"
          case arg
          when "book" then start_booking(chat, edit: edit)
          when "list" then list_bookings(chat, edit: edit)
          else menu(chat, edit: edit)
          end
        when "type" then pick_type(chat, arg, edit: edit)
        when "date" then pick_date(chat, arg, edit: edit)
        when "time" then pick_time(chat, arg, edit: edit)
        when "bike" then pick_bike(chat, arg, edit: edit)
        when "problem" then pick_problem(chat, arg, edit: edit)
        when "confirm" then arg == "yes" ? create_booking(chat, edit: edit) : menu(chat, t("cancelled_draft"), edit: edit)
        when "cancel" then ask_cancel(chat, arg, edit: edit)
        when "cancel_yes" then cancel_booking(chat, arg, edit: edit)
        # A button on a message the shop sent (Notifier). The answer is a new
        # message: editing would wipe the notice, and with it which booking
        # was cancelled.
        when "notice" then start_booking(chat)
        else menu(chat, edit: edit)
        end
      end

      def menu(chat, text = t("menu"), edit: nil)
        chat.reset!
        say(chat, text, keyboard: menu_keyboard, edit: edit)
      end

      def menu_keyboard
        [ [ button(t("menu_book"), "menu:book") ], [ button(t("menu_list"), "menu:list") ] ]
      end

      # --- booking, step by step ---------------------------------------------

      def start_booking(chat, edit: nil)
        types = MaintenanceType.active.ordered.to_a
        if types.none? || WorkingHour.unconfigured?
          chat.reset!
          return say(chat, t("unavailable"), keyboard: menu_keyboard, edit: edit)
        end

        chat.reset!(step: "type")
        keyboard = types.map { |type| [ button("#{type.name} · #{Bookings::Format.duration(type.duration_minutes)}", "type:#{type.id}") ] }
        say(chat, t("pick_type"), keyboard: keyboard, edit: edit)
      end

      def pick_type(chat, arg, edit: nil)
        type = MaintenanceType.active.find_by(id: arg)
        return start_booking(chat, edit: edit) unless type

        chat.remember(type_id: type.id)
        show_dates(chat, type, edit: edit)
      end

      def show_dates(chat, type, edit: nil)
        chat.update!(step: "date")
        dates = available_dates(type)
        back = [ button(t("other_type"), "menu:book") ]
        return say(chat, t("no_dates"), keyboard: [ back ], edit: edit) if dates.none?

        keyboard = rows(dates.map { |date| button(date_label(date), "date:#{date.iso8601}") }, 3) << back
        say(chat, t("pick_date", type: type.name), keyboard: keyboard, edit: edit)
      end

      def pick_date(chat, arg, edit: nil)
        type = draft_type(chat)
        date = Date.iso8601(arg.to_s) rescue nil
        return start_booking(chat, edit: edit) unless type && date

        chat.remember(date: date.iso8601)
        show_times(chat, type, date, edit: edit)
      end

      def show_times(chat, type, date, edit: nil)
        chat.update!(step: "time")
        day = Bookings::Day.new(date)
        starts = day.free_starts(type.duration_minutes)
        back = [ button(t("other_day"), "type:#{type.id}") ]
        return say(chat, t("no_times", date: date_label(date)), keyboard: [ back ], edit: edit) if starts.none?

        hours = "#{MinuteOfDay.format(day.opens_minute)}–#{MinuteOfDay.format(day.closes_minute)}"
        keyboard = rows(starts.map { |start| button(start.strftime("%H:%M"), "time:#{start.iso8601}") }, 4) << back
        say(chat, t("pick_time", date: date_label(date), hours: hours), keyboard: keyboard, edit: edit)
      end

      def pick_time(chat, arg, edit: nil)
        type = draft_type(chat)
        time = Time.zone.iso8601(arg.to_s) rescue nil
        return start_booking(chat, edit: edit) unless type && time

        chat.remember(scheduled_at: time.iso8601)
        show_bikes(chat, edit: edit)
      end

      def show_bikes(chat, edit: nil)
        bikes = chat.client.bikes.active.ordered.to_a
        return ask_bike_name(chat, edit: edit) if bikes.none?

        chat.update!(step: "bike")
        keyboard = bikes.map { |bike| [ button(bike.display_name, "bike:#{bike.id}") ] } << [ button(t("other_bike"), "bike:new") ]
        say(chat, t("pick_bike"), keyboard: keyboard, edit: edit)
      end

      def pick_bike(chat, arg, edit: nil)
        return ask_bike_name(chat, edit: edit) if arg == "new"

        bike = chat.client.bikes.active.find_by(id: arg)
        return show_bikes(chat, edit: edit) unless bike

        chat.remember(bike_id: bike.id, bike_name: nil)
        ask_problem(chat, edit: edit)
      end

      def ask_bike_name(chat, edit: nil)
        chat.update!(step: "bike_name")
        say(chat, t("ask_bike_name"), edit: edit)
      end

      # The quick picks come from Налаштування › Запис (D63). With none set up
      # the question still stands — the client writes their own or skips.
      def ask_problem(chat, edit: nil)
        problems = BookingProblem.ordered.to_a
        chat.update!(step: "problem")
        keyboard = problems.map { |problem| [ button(problem.name, "problem:#{problem.id}") ] }
        keyboard << [ button(t("write_problem"), "problem:write") ] << [ button(t("skip_problem"), "problem:skip") ]
        say(chat, t(problems.any? ? "pick_problem" : "pick_problem_empty"), keyboard: keyboard, edit: edit)
      end

      def pick_problem(chat, arg, edit: nil)
        case arg
        when "write"
          chat.update!(step: "problem_text")
          say(chat, t("ask_problem_text"), edit: edit)
        when "skip"
          chat.remember(problem: nil)
          show_confirm(chat, edit: edit)
        else
          # The text, not the id, goes into the draft: the list can be edited
          # while a client is mid-booking, and what they tapped is what counts.
          # A button whose problem has since been deleted shows the list again.
          problem = BookingProblem.find_by(id: arg) if arg.to_s.match?(/\A\d+\z/)
          return ask_problem(chat, edit: edit) unless problem

          chat.remember(problem: problem.name)
          show_confirm(chat, edit: edit)
        end
      end

      def show_confirm(chat, edit: nil)
        type = draft_type(chat)
        time = draft_time(chat)
        return start_booking(chat, edit: edit) unless type && time

        chat.update!(step: "confirm")
        text = t("confirm", type: type.name, when: when_label(time, type.duration_minutes),
                 bike: draft_bike_name(chat), problem: chat.draft["problem"].presence || t("no_problem"),
                 phone: chat.client.formatted_phone)
        say(chat, text, keyboard: [ [ button(t("confirm_yes"), "confirm:yes"), button(t("confirm_no"), "confirm:no") ] ], edit: edit)
      end

      def create_booking(chat, edit: nil)
        type = draft_type(chat)
        time = draft_time(chat)
        return start_booking(chat, edit: edit) unless type && time

        order = Orders::Create.call(
          accepted_by: User.telegram_bot, client_id: chat.client.id,
          bike_id: chat.draft["bike_id"], bike_name: chat.draft["bike_name"],
          problem: chat.draft["problem"],
          booking: { scheduled_at: time, maintenance_type: type, channel: "telegram" }
        )

        if order.persisted?
          chat.reset!
          text = t("booked", number: order_number(order), when: when_label(order.scheduled_at, order.booking_minutes),
                   type: type.name, bike: order.bike.name)
          say(chat, text, keyboard: menu_keyboard, edit: edit)
        elsif order.errors[:scheduled_at].any?
          # Somebody took the slot between the pick and the tap — back to the
          # times for that day, which no longer offer it.
          chat.remember(scheduled_at: nil)
          say(chat, t("slot_taken"), edit: edit)
          show_times(chat, type, time.to_date)
        else
          errors = (order.errors.full_messages + (order.bike&.errors&.full_messages || [])).uniq.to_sentence
          menu(chat, t("booking_failed", errors: errors), edit: edit)
        end
      end

      # --- existing bookings ------------------------------------------------

      def list_bookings(chat, edit: nil)
        chat.reset!
        orders = upcoming_bookings(chat)
        return say(chat, t("none_booked"), keyboard: menu_keyboard, edit: edit) if orders.none?

        lines = orders.map { |order| t("booking_line", when: when_label(order.scheduled_at, order.booking_minutes), type: order.maintenance_type&.name || t("booking"), bike: order.bike.name) }
        keyboard = orders.map { |order| [ button(t("cancel_button", when: short_when_label(order.scheduled_at)), "cancel:#{order.id}") ] }
        keyboard << [ button(t("menu_back"), "menu:main") ]
        say(chat, [ t("my_bookings"), *lines ].join("\n"), keyboard: keyboard, edit: edit)
      end

      def ask_cancel(chat, arg, edit: nil)
        order = upcoming_bookings(chat).find_by(id: arg)
        return menu(chat, t("cancel_gone"), edit: edit) unless order

        keyboard = [ [ button(t("cancel_yes"), "cancel_yes:#{order.id}"), button(t("cancel_no"), "menu:list") ] ]
        say(chat, t("cancel_confirm", when: when_label(order.scheduled_at, order.booking_minutes)), keyboard: keyboard, edit: edit)
      end

      # Mirrors the cancellation flow in the CRM: a status flip with a reason.
      # Only the client's own, still-booked orders are reachable here.
      def cancel_booking(chat, arg, edit: nil)
        order = upcoming_bookings(chat).find_by(id: arg)
        return menu(chat, t("cancel_gone"), edit: edit) unless order

        order.update!(status: :cancelled, cancelled_at: Time.current, cancel_reason: t("cancel_reason"))
        menu(chat, t("cancelled", when: when_label(order.scheduled_at, order.booking_minutes)), edit: edit)
      end

      def upcoming_bookings(chat)
        chat.client.orders.booked.where(scheduled_at: Date.current.beginning_of_day..)
            .includes(:bike, :maintenance_type).order(:scheduled_at)
      end

      # --- helpers ----------------------------------------------------------

      def available_dates(type)
        range = Date.current..(Date.current + DAYS_AHEAD)
        hours = WorkingHour.all.index_by(&:weekday)
        exceptions = ScheduleException.where(date: range).index_by(&:date)

        range.lazy
             .map { |date| Bookings::Day.new(date, hours: hours[date.wday], exception: exceptions[date]) }
             .select { |day| day.free_starts(type.duration_minutes).any? }
             .first(MAX_DATES).map(&:date)
      end

      def draft_type(chat)
        MaintenanceType.active.find_by(id: chat.draft["type_id"])
      end

      def draft_time(chat)
        Time.zone.iso8601(chat.draft["scheduled_at"].to_s)
      rescue ArgumentError
        nil
      end

      def draft_bike_name(chat)
        chat.draft["bike_name"].presence || chat.client.bikes.find_by(id: chat.draft["bike_id"])&.display_name || "—"
      end

      def rows(buttons, per_row)
        buttons.each_slice(per_row).to_a
      end

      # A tap edits the message its keyboard was on, so the chat does not fill
      # with one bubble per step; a typed reply gets a new message. Telegram
      # refuses to edit a message that is unchanged or too old, and then a new
      # one is the right answer anyway.
      def say(chat, text, keyboard: nil, edit: nil)
        markup = keyboard && { inline_keyboard: keyboard }

        if edit
          begin
            return @api.edit_message_text(chat_id: chat.chat_id, message_id: edit, text: text, reply_markup: markup)
          rescue Api::Error
            # fall through
          end
        end

        @api.send_message(chat_id: chat.chat_id, text: text, reply_markup: markup)
      end
  end
end
