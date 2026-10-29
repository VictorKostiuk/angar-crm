# Stands in for Telegram::Api: records every call instead of making it, and
# hands back whatever updates it was given when polled.
class FakeTelegramApi
  attr_reader :calls
  # An error for send_message to raise instead of recording, the way
  # Telegram refuses a client who blocked the bot.
  attr_accessor :failure

  def initialize(updates: [])
    @calls = []
    @updates = updates
    @next_message_id = 100
  end

  def me = { "username" => "angar_test_bot" }
  def send_message(**args)
    raise failure if failure

    record(:send_message, args)
  end

  def edit_message_text(**args) = record(:edit_message_text, args)
  def answer_callback_query(id, **args) = record(:answer_callback_query, args.merge(id: id))
  def delete_webhook = record(:delete_webhook, {})

  def get_updates(**args)
    record(:get_updates, args)
    @updates.shift || []
  end

  # Every text shown to the person, sent or edited, in order.
  def texts
    calls.filter_map { |name, args| args[:text] if %i[ send_message edit_message_text ].include?(name) }
  end

  def last_text = texts.last

  def last_markup
    calls.reverse.find { |name, _| %i[ send_message edit_message_text ].include?(name) }&.last&.dig(:reply_markup)
  end

  # [[label, callback_data], ...] of the inline keyboard on the last message.
  def buttons
    (last_markup&.dig(:inline_keyboard) || []).flatten.map { |button| [ button[:text], button[:callback_data] ] }
  end

  private
    def record(name, args)
      @calls << [ name, args ]
      { "message_id" => (@next_message_id += 1) }
    end
end
