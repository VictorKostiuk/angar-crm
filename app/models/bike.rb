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

  def display_name
    [ name, size ].compact_blank.join(", ")
  end
end
