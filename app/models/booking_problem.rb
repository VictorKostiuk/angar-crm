# A quick pick the Telegram bot offers when it asks what is wrong with the bike
# (D63). The bot copies the text onto the booking, so renaming or deleting one
# never rewrites an order already made.
class BookingProblem < ApplicationRecord
  # Roughly what fits on a phone-width Telegram button before it is cut with "…".
  NAME_LIMIT = 50

  normalizes :name, with: ->(name) { name.strip.squeeze(" ") }

  validates :name, presence: true, length: { maximum: NAME_LIMIT }

  scope :ordered, -> { order(:position, :id) }
end
