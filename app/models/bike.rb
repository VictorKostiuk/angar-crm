class Bike < ApplicationRecord
  belongs_to :client, counter_cache: :bikes_count
  has_many :orders, dependent: :restrict_with_error

  normalizes :name, with: ->(name) { name.strip.squeeze(" ") }

  validates :name, presence: true

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
    orders.open_orders.any?
  end

  def self.in_shop_ids(bikes)
    Order.open_orders.where(bike_id: bikes.map(&:id)).distinct.pluck(:bike_id).to_set
  end

  def display_name
    [ name, size ].compact_blank.join(", ")
  end
end
