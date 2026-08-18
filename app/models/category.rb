class Category < ApplicationRecord
  enum :kind, { service: 0, part: 1 }

  has_many :services, dependent: :restrict_with_error
  has_many :parts, dependent: :restrict_with_error

  normalizes :name, with: ->(name) { name.strip.squeeze(" ") }

  validates :name, presence: true, uniqueness: { scope: :kind }

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:position, :name) }
end
