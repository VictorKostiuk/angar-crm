class OrderWork < ApplicationRecord
  belongs_to :order, inverse_of: :order_works
  belongs_to :service, optional: true
  belongs_to :mechanic, class_name: "User", optional: true

  normalizes :name, with: ->(name) { name.strip.squeeze(" ") }

  validates :name, presence: true
  validates :quantity, numericality: { greater_than: 0 }
  validates :price, numericality: { greater_than_or_equal_to: 0 }

  before_validation :snapshot_from_service, on: :create
  before_validation :default_mechanic_from_order, on: :create
  before_save :calculate_total

  after_save :recalculate_order_totals
  after_destroy :recalculate_order_totals

  private
    def snapshot_from_service
      return unless service

      self.name = service.name if name.blank?
      self.price = service.base_price if price.nil?
    end

    def default_mechanic_from_order
      self.mechanic_id ||= order&.mechanic_id
    end

    def calculate_total
      self.total = (quantity * price).round(2)
    end

    def recalculate_order_totals
      Orders::RecalculateTotals.call(order)
    end
end
