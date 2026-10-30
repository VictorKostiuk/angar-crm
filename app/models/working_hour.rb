# One row per weekday: when the shop takes bookings, the slot step, and how many
# bookings may overlap (stands / mechanics free at once). A weekday with no row
# is closed — tests and a fresh database load db/structure.sql, which carries no
# seeded rows, so "missing" has to mean something safe.
class WorkingHour < ApplicationRecord
  include MinuteOfDay
  minute_of_day :opens, :closes

  # Monday first, the way a Ukrainian calendar reads.
  WEEK = [ 1, 2, 3, 4, 5, 6, 0 ].freeze

  validates :weekday, inclusion: { in: 0..6 }, uniqueness: true
  validates :slot_minutes, numericality: { only_integer: true, greater_than_or_equal_to: 5, less_than_or_equal_to: 240 }
  validates :capacity, numericality: { only_integer: true, greater_than: 0 }
  validate :closes_after_opens, unless: :closed?

  # All seven weekdays in calendar order, unsaved defaults filling the gaps, so
  # the settings form always shows a full week.
  def self.week
    existing = all.index_by(&:weekday)
    WEEK.map { |wday| existing[wday] || new(weekday: wday, closed: wday.zero?) }
  end

  # Until the week is saved once every day is closed, while the settings form
  # shows unsaved defaults that look configured — both pages say so.
  def self.unconfigured?
    count < WEEK.size
  end

  def day_name
    I18n.t("date.day_names")[weekday].capitalize
  end

  private
    def closes_after_opens
      errors.add(:closes_at, "має бути пізніше за початок") if closes_minute.to_i <= opens_minute.to_i
    end
end
