class RentalBike < ApplicationRecord
  has_many :rentals, dependent: :restrict_with_error

  normalizes :name, with: ->(name) { name.strip.squeeze(" ") }

  validates :name, presence: true
  validates :daily_rate, numericality: { greater_than_or_equal_to: 0 }

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:name) }

  # Out means: a rental exists that has not been returned. Batch-friendly
  # companion below so the fleet list doesn't query once per row.
  def out?
    rentals.outstanding.any?
  end

  def current_rental
    rentals.outstanding.order(:rented_from).last
  end

  def self.out_ids(bikes)
    Rental.outstanding.where(rental_bike_id: bikes.map(&:id)).distinct.pluck(:rental_bike_id).to_set
  end

  def display_name
    [ name, size ].compact_blank.join(", ")
  end
end
