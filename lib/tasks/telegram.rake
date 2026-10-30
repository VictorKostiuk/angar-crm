# The Telegram booking bot (docs/PLAN.md D62).
#
#   bin/rails telegram:poll              long polling — development, or a server with no webhook
#   bin/rails telegram:profile           the bot's description and "/" menu, from uk.yml
#   bin/rails telegram:webhook:set       point Telegram at https://$APP_HOST/telegram/webhook
#   bin/rails "telegram:webhook:set[https://example.com/telegram/webhook]"
#   bin/rails telegram:webhook:info      what Telegram currently has
#   bin/rails telegram:webhook:delete    back to polling
#
# All of them need TELEGRAM_BOT_TOKEN. Locally it lives in .env (git-ignored),
# which bin/dev reads; for a single task: foreman run bin/rails telegram:poll
namespace :telegram do
  desc "Receive Telegram updates by long polling (Ctrl-C to stop)"
  task poll: :environment do
    # Logs line by line even when stdout is a file or a pipe, not a terminal.
    $stdout.sync = true
    api = Telegram::Api.new
    # Polling and a webhook are mutually exclusive on Telegram's side, so
    # polling has to delete the webhook — and with one token shared between
    # a laptop and production, that silently takes the bot off the server.
    webhook = api.webhook_info["url"]
    if webhook.present? && ENV["FORCE"] != "1"
      abort "The bot is connected to #{webhook}. Polling would disconnect it.\n" \
            "Use a separate test bot, or run with FORCE=1 and afterwards restore it with telegram:webhook:set."
    end
    api.delete_webhook
    puts "Polling Telegram as @#{api.me["username"]} — Ctrl-C to stop."
    Telegram::Poller.new(api: api, logger: Logger.new($stdout)).run
  rescue Interrupt
    puts "\nStopped."
  end

  desc "Set the bot's description and command menu (stored by Telegram — once per bot)"
  task profile: :environment do
    api = Telegram::Api.new
    profile = I18n.t("telegram.profile")
    api.set_my_commands(profile[:commands].map { |command, description| { command: command.to_s, description: description } })
    api.set_my_description(profile[:description])
    api.set_my_short_description(profile[:short_description])
    puts "Profile set for @#{api.me["username"]}."
  end

  namespace :webhook do
    desc "Register the webhook with Telegram"
    task :set, [ :url ] => :environment do |_task, args|
      url = args[:url].presence || "https://#{ENV.fetch("APP_HOST")}/telegram/webhook"
      Telegram::Api.new.set_webhook(url: url)
      puts "Webhook set to #{url}"
    end

    desc "Remove the webhook (Telegram then queues updates for polling)"
    task delete: :environment do
      Telegram::Api.new.delete_webhook
      puts "Webhook deleted."
    end

    desc "Show the webhook Telegram currently has"
    task info: :environment do
      puts JSON.pretty_generate(Telegram::Api.new.webhook_info)
    end
  end
end
