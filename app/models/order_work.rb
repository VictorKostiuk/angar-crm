class OrderWork < ApplicationRecord
  belongs_to :order, inverse_of: :order_works
  belongs_to :service, optional: true
  belongs_to :mechanic, class_name: "User", optional: true

  normalizes :name, with: ->(name) { name.strip.squeeze(" ") }

  validates :name, presence: true
  validates :quantity, numericality: { greater_than: 0 }
  validates :price, numericality: { greater_than_or_equal_to: 0 }
  validate :order_must_have_a_mechanic, on: :create

  before_validation :snapshot_from_service, on: :create
  before_validation :default_mechanic_from_order, on: :create
  before_save :calculate_total

  after_save :recalculate_order_totals
  after_destroy :recalculate_order_totals

  private
    # A work line carries the mechanic who earns from it, defaulted from the
    # order below. Added while the order has nobody assigned, it is created
    # with mechanic_id nil and only backfilled at close — so until then it
    # counts toward no one's payroll, and the mechanic card shows the order
    # with «Послуги: 0 грн» while the order itself shows the money. Refusing
    # the line up front is the only version of this that cannot drift.
    #
    # on: :create only — clearing an order's mechanic later must not freeze the
    # inline quantity/price fields on lines that already exist.
    def order_must_have_a_mechanic
      return if order.nil? || order.mechanic_id.present?

      errors.add(:base, "Спочатку призначте механіка замовлення")
    end

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
