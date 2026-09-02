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
  # D33 (2026-08-20, reverses D32 and restores D12/§6 rule 7): payout is
  # works_total — the mechanic's services — times their payroll %. Parts are
  # goods the shop resells, not labour the mechanic performed, so they no
  # longer count toward the earning base. `total` is still computed and shown,
  # but purely as information; it is not what payout multiplies against.
  class MechanicStats
    # D37: a mechanic never earns less than this for an order they performed
    # services on. Applied per order and summed — flooring the period aggregate
    # instead would pay the minimum once no matter how many orders.
    MIN_PAYOUT_PER_ORDER = 100

    Row = Struct.new(:mechanic, :accepted_count, :in_progress_count, :completed_count,
                     :works_total, :parts_total, :works_by_order, :sales_total, :sales_commission,
                     keyword_init: true) do
      def total
        works_total + parts_total
      end

      # Rounded to whole hryvnia, NOT kopiykas: money() renders whole hryvnia
      # everywhere, so a 1977.50 obligation displays as "1 978 грн", gets paid
      # as the 1978 the owner sees, and leaves a −0.50 residual that shows up
      # on the mechanic's card as an unpayable "-1 грн".
      def payout
        # A 0% mechanic is explicitly on no payroll (D12), so the minimum does
        # not manufacture earnings for them.
        return 0 if mechanic.payroll_percent.zero?

        works_by_order.sum do |_order_id, works|
          [ (works * mechanic.payroll_percent / 100).round, MIN_PAYOUT_PER_ORDER ].max
        end
      end

      # Everything the shop owes this person for the period: labour plus their
      # cut of the counter sales they rang up (D40). This — not #payout — is
      # what MechanicDebt, OutstandingPayroll and the payout form settle
      # against, so a commission that Фінанси already subtracts from profit
      # lands in somebody's balance instead of going untracked.
      #
      # #payout stays works-only on purpose: D33 defines it as the labour base,
      # and the roster prints the Послуги × % chain beside it so the figure can
      # be checked on screen rather than taken on faith.
      def earnings
        payout + sales_commission
      end

      # Whether the sales figures are worth their screen space. A shop that
      # pays no commission should not carry three empty tiles on every card,
      # and the block reappears the moment a rate is set or a sale is rung up.
      def sells?
        sales_total.positive? || mechanic.sales_percent.positive?
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
      # Grouped by order so the per-order minimum can be applied; works_total is
      # derived from the same hash so the two can never disagree.
      works_by_order = OrderWork.where(mechanic_id: mechanic.id).joins(:order)
                                .merge(closed_orders_in_range).group(:order_id).sum(:total)
      sales = sales_for(mechanic)

      Row.new(
        mechanic: mechanic,
        accepted_count: Order.where(accepted_by_id: mechanic.id, accepted_at: @range).count,
        in_progress_count: Order.open_orders.where(mechanic_id: mechanic.id).count,
        completed_count: closed_orders_owned_by(mechanic).count,
        works_total: works_by_order.values.sum,
        parts_total: OrderPart.joins(:order).merge(closed_orders_owned_by(mechanic)).sum(:total),
        works_by_order: works_by_order,
        sales_total: sales.sum(&:total),
        sales_commission: sales.sum(&:commission)
      )
    end

    private
      # Summed from each sale's own rounded commission, never as
      # (sales_total × sales_percent).round — SalesController#index sums the
      # per-sale figures, and rounding the aggregate instead would put a
      # different number on this card than on Продажі for the same period and
      # seller. Same drift D30 exists to prevent.
      def sales_for(mechanic)
        Sale.in_range(@range).where(sold_by_id: mechanic.id).includes(:sold_by).to_a
      end

      def closed_orders_in_range
        Order.closed.where(closed_at: @range)
      end

      def closed_orders_owned_by(mechanic)
        closed_orders_in_range.where(mechanic_id: mechanic.id)
      end
  end
end
