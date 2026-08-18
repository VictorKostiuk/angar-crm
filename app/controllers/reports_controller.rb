class ReportsController < ApplicationController
  require_role :admin, :owner

  def index
    @period = PeriodFilter.new(**period_params)
    @mechanics = User.mechanic.order(:name)
    @mechanic = @mechanics.find_by(id: params[:mechanic_id])
    @status = Order.statuses.key?(params[:status]) ? params[:status] : "closed"

    @orders = filtered_orders

    @works_total = OrderWork.where(order_id: @orders.select(:id)).sum(:total)
    @parts_total = OrderPart.where(order_id: @orders.select(:id)).sum(:total)
    @order_count = @orders.count

    @income_by_mechanic = @mechanics.map { |mechanic| income_row(mechanic) }

    # §7: "see all mechanics' payroll" is owner-only — admin gets revenue
    # (the KPI tiles and income breakdown above) but not individual payouts.
    # Payroll only ever reflects closed orders (D12/§6 rule 7) — independent
    # of @status, which just controls the revenue KPIs/breakdown above.
    if Current.user.owner?
      @payroll_rows = Reports::MechanicStats.new(range: @period.range).call
                                             .select { |row| row.mechanic.payroll_percent.positive? }
      @payroll_rows = @payroll_rows.select { |row| row.mechanic == @mechanic } if @mechanic
    end
  end

  private
    def period_params
      params.permit(:period, :from, :to).to_h.symbolize_keys
    end

    # closed orders are dated by when the money was realized (closed_at);
    # everything else has no closed_at yet, so falls back to accepted_at.
    def filtered_orders
      date_column = @status == "closed" ? :closed_at : :accepted_at
      scope = Order.where(status: @status, date_column => @period.range)
      scope = scope.where(mechanic_id: @mechanic.id) if @mechanic
      scope.includes(:client, :bike, :mechanic)
    end

    def income_row(mechanic)
      mechanic_orders = @orders.where(mechanic_id: mechanic.id)
      {
        mechanic: mechanic,
        order_count: mechanic_orders.count,
        works_total: OrderWork.where(order_id: mechanic_orders.select(:id)).sum(:total),
        parts_total: OrderPart.where(order_id: mechanic_orders.select(:id)).sum(:total)
      }
    end
end
