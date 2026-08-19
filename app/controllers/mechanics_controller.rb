class MechanicsController < ApplicationController
  before_action :set_period
  before_action :deny_admin
  before_action :set_mechanic, only: :show
  before_action :require_own_card_or_owner, only: :show

  # §7: only the owner sees the roster ("all mechanics' payroll" is
  # owner-only — admin is denied here, unlike Reports where admin gets
  # revenue but not payroll). A mechanic sees only their own card — index
  # just redirects them there; show (below) is the actual access-control
  # boundary, since a redirect alone doesn't stop a direct URL.
  def index
    if Current.user.mechanic?
      redirect_to mechanic_path(Current.user, period_params)
      return
    end

    @rows = Reports::MechanicStats.new(range: @period.range).call
  end

  def show
    @row = Reports::MechanicStats.new(range: @period.range).row_for(@mechanic)
    @open_orders = @mechanic.assigned_orders.open_orders.includes(:client, :bike).order(:accepted_at)
    @closed_orders = @mechanic.assigned_orders.closed.where(closed_at: @period.range)
                              .includes(:client, :bike).order(closed_at: :desc)
    @works_by_order = OrderWork.where(mechanic_id: @mechanic.id, order_id: @closed_orders.map(&:id))
                                .group(:order_id).sum(:total)

    return unless Current.user.owner?

    @payouts = @mechanic.payroll_payouts.ordered
    @outstanding = Finances::OutstandingPayroll.call(mechanic: @mechanic, month: @period.from.to_date) if @period.period == "month"
  end

  private
    def set_period
      @period = PeriodFilter.new(**period_params)
    end

    def period_params
      params.permit(:period, :from, :to).to_h.symbolize_keys
    end

    def set_mechanic
      @mechanic = User.assignable_as_mechanic.find(params[:id])
    end

    def deny_admin
      return unless Current.user.admin?

      redirect_to root_path, alert: "Недостатньо прав доступу."
    end

    def require_own_card_or_owner
      return if Current.user.owner?
      return if @mechanic.id == Current.user.id

      redirect_to root_path, alert: "Недостатньо прав доступу."
    end
end
