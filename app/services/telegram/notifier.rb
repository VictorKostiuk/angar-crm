module Telegram
  # Messages the shop sends a client through the bot, outside any conversation
  # the client started (D64): the bike is ready, a booking was cancelled.
  #
  # Sent inside the request, not from a job. The person who pressed the button
  # sees right away whether the message arrived, and an in-process job queue
  # would lose it on a restart with nobody noticing. The API client gets a
  # short timeout for the same reason: someone is waiting.
  #
  # Plain text, no parse_mode — a bike called "Trek_X *Pro*" must not break
  # the message as Markdown.
  class Notifier
    include Wording

    class_attribute :api_factory, default: -> { Api.new(read_timeout: 5) }

    Result = Data.define(:error) do
      def sent? = error.nil?
    end

    NETWORK_ERRORS = [ SystemCallError, SocketError, IOError, Timeout::Error, OpenSSL::SSL::SSLError ].freeze

    # Whether there is anyone to send to: the bot is on and this client has
    # shared their phone with it.
    def self.available_for?(client)
      Api.configured? && client.telegram_chat.present?
    end

    # The text is the same one the ready-message modal shows for copying.
    def ready(order, text)
      deliver(order.client, text)
    end

    # With a button straight back into booking, since the client most likely
    # wants another time rather than none. "notice:book", not the menu's
    # "menu:book": the bot answers it with a new message and leaves this one
    # standing.
    def booking_cancelled(order)
      text = t("notice_booking_cancelled", when: when_label(order.scheduled_at, order.booking_minutes),
               type: order.maintenance_type&.name || t("booking"))
      deliver(order.client, text, keyboard: [ [ button(t("menu_book"), "notice:book") ] ])
    end

    private
      def deliver(client, text, keyboard: nil)
        chat = client.telegram_chat
        return Result.new(error: t("notice_errors.not_linked")) unless chat

        api_factory.call.send_message(chat_id: chat.chat_id, text: text, reply_markup: keyboard && { inline_keyboard: keyboard })
        Result.new(error: nil)
      rescue Api::NotConfigured
        Result.new(error: t("notice_errors.not_configured"))
      rescue Api::Error => e
        Rails.logger.warn("telegram: notice to client #{client.id} failed: #{e.message}")
        Result.new(error: explain(e))
      rescue *NETWORK_ERRORS => e
        Rails.logger.warn("telegram: notice to client #{client.id} failed: #{e.class}: #{e.message}")
        Result.new(error: t("notice_errors.unreachable"))
      end

      # 403 is the client having blocked the bot; 400 "chat not found" a chat
      # Telegram no longer has. Both are the client's side, not a fault here.
      def explain(error)
        case error.code
        when 403 then t("notice_errors.blocked")
        when 400 then t("notice_errors.chat_gone")
        else t("notice_errors.failed")
        end
      end
  end
end
