class Discount < ApplicationRecord
  enum :kind, { percentage: 0, fixed_amount: 1 }

  normalizes :name, with: ->(name) { name.strip.squeeze(" ") }

  validates :name, presence: true
  validates :value, numericality: { greater_than: 0 }
  validates :value, numericality: { less_than_or_equal_to: 100 }, if: :percentage?

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:name) }
end
