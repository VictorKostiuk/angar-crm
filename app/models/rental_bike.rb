class RentalBike < ApplicationRecord
  has_many :rentals, dependent: :restrict_with_error
  # Documents and condition shots for the bike — the same treatment orders get.
  has_many_attached :photos

  normalizes :name, with: ->(name) { name.strip.squeeze(" ") }

  validates :name, presence: true
  validates :daily_rate, numericality: { greater_than_or_equal_to: 0 }

  validate :photos_must_be_images

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

  private
    def photos_must_be_images
      return unless photos.attached?

      errors.add(:photos, "має бути зображенням") unless photos.all? { |p| p.content_type.to_s.start_with?("image/") }
    end
end
