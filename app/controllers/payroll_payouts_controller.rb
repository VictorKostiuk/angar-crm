class PayrollPayoutsController < ApplicationController
  require_role :owner
  layout "modal", only: %i[ new create ]

  before_action :set_mechanic

  def new
    @payout = @mechanic.payroll_payouts.new(
      period_month: Date.current.beginning_of_month,
      amount: Finances::OutstandingPayroll.call(mechanic: @mechanic).clamp(0..)
    )
  end

  def create
    @payout = @mechanic.payroll_payouts.new(payout_params)
    @payout.recorded_by = Current.user

    if @payout.save
      redirect_to mechanic_path(@mechanic), notice: "Виплату записано."
    else
      render :new, status: :unprocessable_entity
    end
  end

  private
    def set_mechanic
      @mechanic = User.mechanic.find(params[:mechanic_id])
    end

    def payout_params
      params.expect(payroll_payout: %i[ amount period_month note ])
    end
end
