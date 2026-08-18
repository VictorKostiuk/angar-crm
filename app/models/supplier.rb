class Supplier < ApplicationRecord
  has_many :parts, dependent: :nullify

  normalizes :name, with: ->(name) { name.strip.squeeze(" ") }

  validates :name, presence: true

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:name) }
end
