class FinancesController < ApplicationController
  require_role :admin, :owner

  def index
    @period = PeriodFilter.new(**period_params)

    revenue = Reports::ClosedRevenue.call(range: @period.range)
    @revenue = revenue[:works_total] + revenue[:parts_total]
    # The breakdown behind the Дохід tile. Deliberately the same order set and
    # the same line-level sums ClosedRevenue uses — reading the orders' cached
    # works_total/parts_total columns instead would let the table disagree with
    # the tile above it the moment a cached column drifted (D30).
    @closed_orders = Order.closed.where(closed_at: @period.range)
                          .includes(:client, :bike).order(closed_at: :desc)
    order_ids = @closed_orders.map(&:id)
    @works_by_order = OrderWork.where(order_id: order_ids).group(:order_id).sum(:total)
    @parts_by_order = OrderPart.where(order_id: order_ids).group(:order_id).sum(:total)

    @expenses_total = Expense.in_range(@period.range).sum(:amount)
    @profit_before_payouts = @revenue - @expenses_total

    return unless Current.user.owner?

    @payouts_total = PayrollPayout.where(period_month: @period.range).sum(:amount)
    @net_profit = @profit_before_payouts - @payouts_total
  end

  private
    def period_params
      params.permit(:period, :from, :to).to_h.symbolize_keys
    end
end
