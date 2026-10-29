class Bike < ApplicationRecord
  belongs_to :client, counter_cache: :bikes_count
  has_many :orders, dependent: :restrict_with_error
  # The bike itself, kept across visits. Intake photos stay on each order
  # (they record its condition on that day); #cover_photo falls back to them.
  has_many_attached :photos

  normalizes :name, with: ->(name) { name.strip.squeeze(" ") }

  validates :name, presence: true
  validate :photos_must_be_images

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:name) }
  scope :search, ->(query) {
    next all if query.blank?

    left_joins(:client).where("bikes.name ILIKE :q OR clients.name ILIKE :q", q: "%#{query}%")
  }

  # A bike is in the shop while any of its orders is still open; once they are
  # all closed or cancelled it has been handed back. Batch-friendly companion
  # below so a list doesn't issue one query per row.
  def in_shop?
    orders.in_shop.any?
  end

  def self.in_shop_ids(bikes)
    Order.in_shop.where(bike_id: bikes.map(&:id)).distinct.pluck(:bike_id).to_set
  end

  def display_name
    [ name, size ].compact_blank.join(", ")
  end

  # The bike's own photo, else the newest intake photo from any of its orders —
  # most bikes were only ever photographed at the counter. Reads loaded
  # associations, so a list that preloads both stays one query per table.
  def cover_photo
    photos.first || order_photos.first
  end

  def order_photos
    orders.sort_by(&:accepted_at).reverse.flat_map(&:photos)
  end

  private
    def photos_must_be_images
      return unless photos.attached?

      errors.add(:photos, "має бути зображенням") unless photos.all? { |p| p.content_type.to_s.start_with?("image/") }
    end
end
