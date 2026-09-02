class Rental < ApplicationRecord
  belongs_to :rental_bike
  belongs_to :client, optional: true
  belongs_to :issued_by, class_name: "User"
  # Photos of the renter's ID, taken at handover — the shop's only hold on a
  # bike going out to someone who is not in the client base.
  has_many_attached :documents

  validates :rented_from, :rented_to, presence: true
  validate :dates_in_order
  validate :bike_must_be_free, on: :create
  validate :documents_must_be_images

  before_validation :snapshot_rate
  before_validation :calculate_amount

  scope :outstanding, -> { where(returned_at: nil) }
  scope :returned, -> { where.not(returned_at: nil) }
  scope :ordered, -> { order(rented_from: :desc, created_at: :desc) }
  # Rental income is recognised when the bike goes out, which is when the money
  # changes hands — so the period filter reads rented_from, not returned_at.
  scope :in_range, ->(range) { where(rented_from: range) }

  def days
    return 0 if rented_from.blank? || rented_to.blank?

    # Nights, not inclusive days: 20.08 → 22.08 is 2 доби, per the worked
    # example this was specified with. Same-day out-and-back still bills one.
    [ (rented_to - rented_from).to_i, 1 ].max
  end

  def renter
    client&.name.presence || renter_name.presence || "—"
  end

  def out?
    returned_at.nil?
  end

  private
    # The rate is copied onto the rental, so changing a bike's price later
    # never rewrites what a past hire cost.
    def snapshot_rate
      self.daily_rate = rental_bike.daily_rate if daily_rate.to_d.zero? && rental_bike
    end

    def calculate_amount
      self.amount = daily_rate.to_d * days
    end

    def dates_in_order
      return if rented_from.blank? || rented_to.blank?

      errors.add(:rented_to, "не може бути раніше за дату видачі") if rented_to < rented_from
    end

    def documents_must_be_images
      return unless documents.attached?

      errors.add(:documents, "має бути зображенням") unless documents.all? { |d| d.content_type.to_s.start_with?("image/") }
    end

    def bike_must_be_free
      return if rental_bike.blank?

      errors.add(:rental_bike, "вже у прокаті") if rental_bike.rentals.outstanding.exists?
    end
end
