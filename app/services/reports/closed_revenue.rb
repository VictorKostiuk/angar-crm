module Reports
  # Shop-wide closed-order revenue for a period, no mechanic filter. Shared
  # by Фінанси's P&L (P8.3) and Звіти's default KPI tiles (status = closed,
  # no mechanic selected) so the two screens can never disagree about what
  # "revenue" means (docs/PLAN.md D30). Deliberately NOT
  # MechanicStats.call.sum(&:total): MechanicStats rows are keyed by
  # User.mechanic, so an order whose mechanic_id points at an admin/owner
  # (nothing in the schema forbids this) would silently vanish from that sum.
  class ClosedRevenue
    def self.call(...) = new(...).call

    def initialize(range:)
      @range = range
    end

    def call
      orders = Order.closed.where(closed_at: @range)
      {
        works_total: OrderWork.where(order_id: orders.select(:id)).sum(:total),
        parts_total: OrderPart.where(order_id: orders.select(:id)).sum(:total),
        order_count: orders.count
      }
    end
  end
end
