# The LED destination-sign ticker in the header. One shop, one sign — this is a
# singleton row, not a collection, so there is no index/new/destroy anywhere.
class Announcement < ApplicationRecord
  MAX_LENGTH = 200

  validates :text, length: { maximum: MAX_LENGTH }

  # Read-only lookup: this runs in shared/_shell on *every* page render, so it
  # must never write (no first_or_create!). The row is created the first time
  # the owner saves the form.
  def self.current
    first || new
  end

  # `active` and a blank text are two ways of saying "off" — this is the single
  # gate the header checks, so an empty dark box can never appear.
  def visible?
    active? && text.present?
  end

  # Seconds for one full loop. Long text has to move faster or a lap takes the
  # better part of a minute; short text has to move slowly or it flicks past.
  def scroll_duration
    (text.to_s.length / 6.0).clamp(8, 30).round
  end
end
