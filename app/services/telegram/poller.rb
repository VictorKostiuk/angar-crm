module Telegram
  # Long polling for environments without a public HTTPS address — a laptop
  # in development, or a server before its webhook is set. Production uses the
  # webhook (Telegram::WebhooksController); the two must not run at once, which
  # is why the rake task deletes the webhook before polling.
  #
  # One failing update must not stall the rest of its batch, so each is
  # rescued and logged on its own. Network trouble waits and retries; the
  # loop only ends on #stop or an Interrupt.
  class Poller
    RETRY_WAIT = 5

    def initialize(api: Api.new, bot: Bot.new(api: api), logger: Rails.logger, timeout: 30, retry_wait: RETRY_WAIT)
      @api = api
      @bot = bot
      @logger = logger
      @timeout = timeout
      @retry_wait = retry_wait
      @offset = nil
      @running = false
    end

    def run(once: false)
      @running = true

      while @running
        poll
        break if once
      end
    end

    def stop
      @running = false
    end

    private
      def poll
        @api.get_updates(offset: @offset, timeout: @timeout).each do |update|
          # Confirmed to Telegram by the next request's offset, so a crash
          # mid-batch re-delivers only what was not finished.
          @offset = update["update_id"] + 1
          handle(update)
        end
      rescue Api::Error, SystemCallError, SocketError, IOError, Timeout::Error => e
        @logger.warn("telegram: polling failed (#{e.class}: #{e.message}); retrying in #{@retry_wait}s")
        sleep @retry_wait if @running
      end

      def handle(update)
        @bot.handle(update)
      rescue StandardError => e
        @logger.error("telegram: update #{update["update_id"]} failed: #{e.class}: #{e.message}")
      end
  end
end
