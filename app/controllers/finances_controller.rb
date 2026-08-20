class FinancesController < ApplicationController
  require_role :admin, :owner

  # Two zones on one page, and they deliberately read different params:
  #
  #   1. The P&L — period only. `Дохід − Витрати = Прибуток до виплат` holds
  #      precisely because nothing here is scoped to a mechanic; expenses are
  #      not attributable to one, so filtering the tiles by mechanic would make
  #      the arithmetic silently stop adding up.
  #   2. The breakdown — period + mechanic + status, with its own filter row
  #      directly above it so the scope of those filters is visible.
  #
  # Absorbed from the former Звіти page (D35).
  def index
    @period = PeriodFilter.new(**period_params)

    load_profit_and_loss
    load_breakdown

    return unless Current.user.owner?

    @payouts_total = PayrollPayout.paid_in(@period.range).sum(:amount)
    @net_profit = @profit_before_payouts - @payouts_total
    # A standing balance, not a period figure — see Finances::MechanicDebt.
    @mechanic_debt = Finances::MechanicDebt.new.total

    # §7: "see all mechanics' payroll" is owner-only — an admin gets revenue and
    # the income breakdown above, but never individual payouts. Payroll only
    # ever reflects closed orders (D12/§6 rule 7), independent of @status, which
    # scopes the revenue breakdown alone.
    @payroll_rows = Reports::MechanicStats.new(range: @period.range).call
                                          .select { |row| row.mechanic.payroll_percent.positive? }
    @payroll_rows = @payroll_rows.select { |row| row.mechanic == @mechanic } if @mechanic
  end

  private
    def period_params
      params.permit(:period, :from, :to).to_h.symbolize_keys
    end

    def load_profit_and_loss
      revenue = Reports::ClosedRevenue.call(range: @period.range)
      @revenue = revenue[:works_total] + revenue[:parts_total]

      # The breakdown behind the Дохід tile. Deliberately the same order set and
      # the same line-level sums ClosedRevenue uses — reading the orders' cached
      # works_total/parts_total columns instead would let the table disagree
      # with the tile above it the moment a cached column drifted (D30).
      @closed_orders = Order.closed.where(closed_at: @period.range)
                            .includes(:client, :bike).order(closed_at: :desc)
      order_ids = @closed_orders.map(&:id)
      @works_by_order = OrderWork.where(order_id: order_ids).group(:order_id).sum(:total)
      @parts_by_order = OrderPart.where(order_id: order_ids).group(:order_id).sum(:total)

      # Sales and rentals are their own revenue lines, deliberately NOT folded
      # into @revenue: Дохід must stay exactly Reports::ClosedRevenue so the
      # order breakdown below it can never disagree with it (D30).
      @sales_total = Sale.in_range(@period.range).sum(:total)
      @rentals_total = Rental.in_range(@period.range).sum(:amount)
      @sales_commission = Sale.in_range(@period.range).includes(:sold_by).sum(&:commission)
      @expenses_total = Expense.in_range(@period.range).sum(:amount)
      @profit_before_payouts = @revenue + @sales_total + @rentals_total - @expenses_total - @sales_commission
    end

    def load_breakdown
      @mechanics = User.assignable_as_mechanic.order(:name)
      @mechanic = @mechanics.find_by(id: params[:mechanic_id])
      @status = Order.statuses.key?(params[:status]) ? params[:status] : "closed"
      @breakdown_orders = breakdown_scope

      if @status == "closed" && @mechanic.nil?
        # Same computation the P&L above uses (D30), so with the default filters
        # the two zones cannot disagree about what revenue means.
        totals = Reports::ClosedRevenue.call(range: @period.range)
        @breakdown_works = totals[:works_total]
        @breakdown_parts = totals[:parts_total]
        @breakdown_count = totals[:order_count]
      else
        @breakdown_works = OrderWork.where(order_id: @breakdown_orders.select(:id)).sum(:total)
        @breakdown_parts = OrderPart.where(order_id: @breakdown_orders.select(:id)).sum(:total)
        @breakdown_count = @breakdown_orders.count
      end

      @income_by_mechanic = @mechanics.map { |mechanic| income_row(mechanic) }
    end

    # Closed orders are dated by when the money was realized (closed_at);
    # everything else has no closed_at yet, so falls back to accepted_at.
    def breakdown_scope
      date_column = @status == "closed" ? :closed_at : :accepted_at
      scope = Order.where(status: @status, date_column => @period.range)
      scope = scope.where(mechanic_id: @mechanic.id) if @mechanic
      scope.includes(:client, :bike, :mechanic)
    end

    def income_row(mechanic)
      mechanic_orders = @breakdown_orders.where(mechanic_id: mechanic.id)
      {
        mechanic: mechanic,
        order_count: mechanic_orders.count,
        works_total: OrderWork.where(order_id: mechanic_orders.select(:id)).sum(:total),
        parts_total: OrderPart.where(order_id: mechanic_orders.select(:id)).sum(:total)
      }
    end
end
