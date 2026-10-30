# A kind of ТО a client books — «Базове ТО», «Повне ТО» — and how long it holds
# a place on the schedule. The duration is copied onto each booking
# (orders.booking_minutes), so retiming a type never moves bookings already made.
class MaintenanceType < ApplicationRecord
  has_many :orders, dependent: :restrict_with_error

  normalizes :name, with: ->(name) { name.strip.squeeze(" ") }

  validates :name, presence: true
  validates :duration_minutes, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 24 * 60 }

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:position, :name) }

  def label
    "#{name} (#{Bookings::Format.duration(duration_minutes)})"
  end
end
