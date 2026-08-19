class StatisticsController < ApplicationController
  require_role :owner

  # Settings' "Статистика" tab (you asked for it) — a consolidated view over
  # the same numbers Фінанси and Звіти already compute (Reports::ClosedRevenue,
  # Reports::MechanicStats), not a replacement for either page.
  def index
    @period = PeriodFilter.new(**period_params)

    revenue = Reports::ClosedRevenue.call(range: @period.range)
    @works_total = revenue[:works_total]
    @parts_total = revenue[:parts_total]
    @revenue = @works_total + @parts_total
    @order_count = revenue[:order_count]

    @expenses_total = Expense.in_range(@period.range).sum(:amount)
    @profit_before_payouts = @revenue - @expenses_total
    @payouts_total = PayrollPayout.where(period_month: @period.range).sum(:amount)
    @net_profit = @profit_before_payouts - @payouts_total

    @mechanics = User.assignable_as_mechanic.order(:name)
    @income_by_mechanic = @mechanics.map { |mechanic| income_row(mechanic) }
    @payroll_rows = Reports::MechanicStats.new(range: @period.range).call

    @summary_chart = summary_chart_config
    @mechanic_chart = mechanic_chart_config
  end

  private
    def period_params
      params.permit(:period, :from, :to).to_h.symbolize_keys
    end

    def summary_chart_config
      {
        type: "bar",
        data: {
          labels: [ "Дохід", "Витрати", "Виплати механікам", "Чистий прибуток" ],
          datasets: [ {
            data: [ @revenue, @expenses_total, @payouts_total, @net_profit ].map(&:to_f),
            backgroundColor: [ "#ea580c", "#9ca3af", "#9ca3af", @net_profit.negative? ? "#dc2626" : "#16a34a" ]
          } ]
        },
        options: {
          responsive: true,
          maintainAspectRatio: false,
          plugins: { legend: { display: false } },
          scales: { y: { beginAtZero: true } }
        }
      }
    end

    def mechanic_chart_config
      {
        type: "bar",
        data: {
          labels: @income_by_mechanic.map { |row| row[:mechanic].name },
          datasets: [
            { label: "Роботи", data: @income_by_mechanic.map { |row| row[:works_total].to_f }, backgroundColor: "#ea580c" },
            { label: "Деталі", data: @income_by_mechanic.map { |row| row[:parts_total].to_f }, backgroundColor: "#0ea5e9" }
          ]
        },
        options: {
          responsive: true,
          maintainAspectRatio: false,
          plugins: { legend: { position: "bottom" } },
          scales: { x: { stacked: true }, y: { stacked: true, beginAtZero: true } }
        }
      }
    end

    def income_row(mechanic)
      mechanic_orders = Order.closed.where(mechanic_id: mechanic.id, closed_at: @period.range)
      {
        mechanic: mechanic,
        order_count: mechanic_orders.count,
        works_total: OrderWork.where(order_id: mechanic_orders.select(:id)).sum(:total),
        parts_total: OrderPart.where(order_id: mechanic_orders.select(:id)).sum(:total)
      }
    end
end
