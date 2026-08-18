class OrderPart < ApplicationRecord
  belongs_to :order, inverse_of: :order_parts
  belongs_to :part, optional: true

  normalizes :name, with: ->(name) { name.strip.squeeze(" ") }

  validates :name, presence: true
  validates :quantity, numericality: { greater_than: 0, only_integer: true }
  validates :price, numericality: { greater_than_or_equal_to: 0 }

  before_validation :snapshot_from_part, on: :create
  before_save :calculate_total

  after_save :recalculate_order_totals
  after_destroy :recalculate_order_totals

  private
    def snapshot_from_part
      return unless part

      self.name = part.name if name.blank?
      self.price = part.base_price if price.nil?
    end

    def calculate_total
      self.total = (quantity * price).round(2)
    end

    def recalculate_order_totals
      Orders::RecalculateTotals.call(order)
    end
end
