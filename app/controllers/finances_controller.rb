class FinancesController < ApplicationController
  require_role :admin, :owner

  def index
    @period = PeriodFilter.new(**period_params)

    revenue = Reports::ClosedRevenue.call(range: @period.range)
    @revenue = revenue[:works_total] + revenue[:parts_total]
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
