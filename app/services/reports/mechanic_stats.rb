module Reports
  # Single source of truth for per-mechanic period stats — read by the
  # mechanics list, the mechanic card, and the reports payroll table, so
  # the same number never gets computed two different (and disagreeing) ways.
  #
  # works_total is attributed by the work line's own mechanic_id, not the
  # order's mechanic_id — a line can be attributed to a different mechanic
  # than the order it lives on (backfilled at close time only for lines
  # that were still nil). Parts have no per-line mechanic (D11 is
  # works-only), so parts_total is attributed by order ownership
  # (order.mechanic_id) instead.
  #
  # D32 (supersedes D12/§6 rule 7): payout is the full order total — works
  # and parts — times the mechanic's payroll %, not works alone.
  class MechanicStats
    Row = Struct.new(:mechanic, :accepted_count, :in_progress_count, :completed_count, :works_total, :parts_total, keyword_init: true) do
      def total
        works_total + parts_total
      end

      def payout
        (total * mechanic.payroll_percent / 100).round(2)
      end
    end

    def self.call(...) = new(...).call

    def initialize(range:)
      @range = range
    end

    def call
      User.assignable_as_mechanic.order(:name).map { |mechanic| row_for(mechanic) }
    end

    def row_for(mechanic)
      Row.new(
        mechanic: mechanic,
        accepted_count: Order.where(accepted_by_id: mechanic.id, accepted_at: @range).count,
        in_progress_count: Order.open_orders.where(mechanic_id: mechanic.id).count,
        completed_count: closed_orders_owned_by(mechanic).count,
        works_total: OrderWork.where(mechanic_id: mechanic.id).joins(:order).merge(closed_orders_in_range).sum(:total),
        parts_total: OrderPart.joins(:order).merge(closed_orders_owned_by(mechanic)).sum(:total)
      )
    end

    private
      def closed_orders_in_range
        Order.closed.where(closed_at: @range)
      end

      def closed_orders_owned_by(mechanic)
        closed_orders_in_range.where(mechanic_id: mechanic.id)
      end
  end
end
