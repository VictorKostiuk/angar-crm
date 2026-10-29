# A private chat with the Telegram bot. Linked to a Client once the person has
# shared their phone; until then the bot only ever asks for it. `step` and
# `draft` are the conversation's state (see Telegram::Bot) — kept here rather
# than in memory so a restart, or a second web process, carries on mid-booking.
class TelegramChat < ApplicationRecord
  belongs_to :client, optional: true

  validates :chat_id, presence: true, uniqueness: true

  def linked?
    client.present?
  end

  def remember(values)
    update!(draft: draft.merge(values.stringify_keys))
  end

  def reset!(step: "menu")
    update!(step: step, draft: {})
  end
end
