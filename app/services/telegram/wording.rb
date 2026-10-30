module Telegram
  # How the bot names days, times and orders. Shared by the conversation (Bot)
  # and the messages the shop sends on its own (Notifier), so a booking reads
  # the same in both.
  module Wording
    private
      def date_label(date)
        "#{t("weekdays")[date.wday]} #{date.strftime("%d.%m")}"
      end

      def when_label(time, minutes)
        "#{date_label(time.to_date)}, #{time.strftime("%H:%M")}–#{(time + minutes.to_i.minutes).strftime("%H:%M")}"
      end

      def short_when_label(time)
        "#{time.strftime("%d.%m")} #{time.strftime("%H:%M")}"
      end

      def order_number(order)
        "##{format("%03d", order.number)}"
      end

      def button(text, data)
        { text: text, callback_data: data }
      end

      def t(key, **options)
        I18n.t("telegram.#{key}", **options)
      end
  end
end
