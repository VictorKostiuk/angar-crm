class Bike < ApplicationRecord
  belongs_to :client, counter_cache: :bikes_count
  has_many :orders, dependent: :restrict_with_error

  normalizes :name, with: ->(name) { name.strip.squeeze(" ") }

  validates :name, presence: true

  scope :active, -> { where(active: true) }

  def display_name
    [ name, size ].compact_blank.join(", ")
  end
end
