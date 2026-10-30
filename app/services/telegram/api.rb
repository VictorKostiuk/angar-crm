require "net/http"

module Telegram
  # The thin HTTP layer over Telegram's Bot API — one method per call the bot
  # makes, nothing clever. Net::HTTP rather than a gem: the surface is a
  # handful of methods, and the project avoids dependencies it can write in a
  # page (D52).
  #
  # Errors never carry the URL, because the URL carries the token.
  class Api
    class Error < StandardError
      attr_reader :code

      def initialize(message, code: nil)
        super(message)
        @code = code
      end
    end

    class NotConfigured < Error; end

    HOST = "api.telegram.org"
    ALLOWED_UPDATES = %w[ message callback_query ].freeze

    # production.env carries the token in production; credentials are the
    # fallback for a machine without an env file.
    def self.token
      ENV["TELEGRAM_BOT_TOKEN"].presence || Rails.application.credentials.dig(:telegram, :bot_token).presence
    end

    def self.configured?
      token.present?
    end

    # The secret Telegram echoes on every webhook delivery, derived from the
    # token so there is nothing else to configure or rotate separately.
    def self.webhook_secret
      Digest::SHA256.hexdigest("angar-crm-telegram-webhook:#{token}")[0, 48]
    end

    # read_timeout is per call; a request a person is waiting on (Notifier)
    # asks for less than the bot's default.
    def initialize(token: self.class.token, read_timeout: 15)
      raise NotConfigured, "TELEGRAM_BOT_TOKEN is not set" if token.blank?

      @token = token
      @read_timeout = read_timeout
    end

    def me
      call("getMe", {})
    end

    def send_message(chat_id:, text:, reply_markup: nil)
      call("sendMessage", { chat_id: chat_id, text: text, reply_markup: reply_markup }.compact)
    end

    def edit_message_text(chat_id:, message_id:, text:, reply_markup: nil)
      call("editMessageText", { chat_id: chat_id, message_id: message_id, text: text, reply_markup: reply_markup }.compact)
    end

    def answer_callback_query(id, text: nil)
      call("answerCallbackQuery", { callback_query_id: id, text: text }.compact)
    end

    # Long polling: Telegram holds the request open up to `timeout` seconds,
    # so the socket has to wait longer than that.
    def get_updates(offset: nil, timeout: 30)
      call("getUpdates", { offset: offset, timeout: timeout, allowed_updates: ALLOWED_UPDATES }.compact,
           read_timeout: timeout + 10)
    end

    def set_webhook(url:)
      call("setWebhook", { url: url, secret_token: self.class.webhook_secret, allowed_updates: ALLOWED_UPDATES })
    end

    def delete_webhook
      call("deleteWebhook", {})
    end

    def webhook_info
      call("getWebhookInfo", {})
    end

    # The bot's profile: the "/" menu and the text an empty chat shows before
    # /start. Stored by Telegram, so set once per bot, not per server.
    def set_my_commands(commands)
      call("setMyCommands", { commands: commands })
    end

    def set_my_description(description)
      call("setMyDescription", { description: description })
    end

    def set_my_short_description(short_description)
      call("setMyShortDescription", { short_description: short_description })
    end

    private
      def call(method, params, read_timeout: @read_timeout)
        http = Net::HTTP.new(HOST, 443)
        http.use_ssl = true
        http.open_timeout = 5
        http.read_timeout = read_timeout

        request = Net::HTTP::Post.new("/bot#{@token}/#{method}", "Content-Type" => "application/json")
        request.body = params.to_json
        response = http.request(request)

        body = JSON.parse(response.body)
        raise Error.new("#{method}: #{body["description"]}", code: body["error_code"]) unless body["ok"]

        body["result"]
      rescue JSON::ParserError
        raise Error, "#{method}: Telegram answered HTTP #{response&.code} with no JSON"
      end
  end
end
