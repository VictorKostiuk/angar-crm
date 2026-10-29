# A single date that differs from its weekday — a shortened day before a
# holiday, a day off, fewer places when someone is on leave. Any field left
# blank falls back to the weekday's own value.
class ScheduleException < ApplicationRecord
  include MinuteOfDay
  minute_of_day :opens, :closes

  validates :date, presence: true, uniqueness: true
  validates :capacity, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validate :closes_after_opens, unless: :closed?

  scope :upcoming, -> { where(date: Date.current..).order(:date) }

  private
    def closes_after_opens
      return if opens_minute.nil? || closes_minute.nil?

      errors.add(:closes_at, "має бути пізніше за початок") if closes_minute <= opens_minute
    end
end
