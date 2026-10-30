module Telegram
  # Where Telegram delivers updates in production. ActionController::Base, not
  # ApplicationController: there is no signed-in person here, no layout, and
  # the browser allow-list would reject Telegram's user agent.
  #
  # Telegram retries any delivery that does not get a 2xx, so a malformed or
  # failing update is logged and answered 200 rather than redelivered forever.
  class WebhooksController < ActionController::Base
    skip_forgery_protection

    # How the bot is built, so a test can hand it a fake API.
    class_attribute :bot_factory, default: -> { Bot.new }

    before_action :verify_secret

    def create
      bot_factory.call.handle(JSON.parse(request.raw_post))
      head :ok
    rescue JSON::ParserError
      head :bad_request
    rescue StandardError => e
      Rails.logger.error("telegram: webhook update failed: #{e.class}: #{e.message}")
      head :ok
    end

    private
      # The secret is set with the webhook and echoed by Telegram in a header;
      # without a configured bot there is no secret, and no endpoint.
      def verify_secret
        return head :not_found unless Api.configured?

        given = request.headers["X-Telegram-Bot-Api-Secret-Token"].to_s
        head :forbidden unless ActiveSupport::SecurityUtils.secure_compare(given, Api.webhook_secret)
      end
  end
end
