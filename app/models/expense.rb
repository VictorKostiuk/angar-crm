class Expense < ApplicationRecord
  belongs_to :user
  belongs_to :stock_movement, optional: true

  normalizes :category, with: ->(category) { category.strip.squeeze(" ") }

  validates :category, presence: true
  validates :amount, numericality: { greater_than: 0 }
  validates :date, presence: true

  scope :ordered, -> { order(date: :desc, created_at: :desc) }
  scope :in_range, ->(range) { where(date: range) }

  def auto_logged?
    stock_movement_id.present?
  end
end
