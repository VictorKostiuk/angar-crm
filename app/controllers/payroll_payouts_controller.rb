class PayrollPayoutsController < ApplicationController
  require_role :owner
  layout "modal", only: %i[ new create ]

  before_action :set_mechanic

  def new
    load_month_summary
    @payout = @mechanic.payroll_payouts.new(period_month: @month, paid_on: Date.current,
                                            amount: @outstanding.clamp(0..))
  end

  def create
    @payout = @mechanic.payroll_payouts.new(payout_params)
    @payout.recorded_by = Current.user

    if @payout.save
      redirect_to mechanic_path(@mechanic), notice: "Виплату записано."
    else
      load_month_summary
      render "shared/modal_form_error", locals: { form_template: "payroll_payouts/new" }, status: :unprocessable_entity
    end
  end

  private
    # The month comes from the page the modal was opened over, so the prefill
    # can never disagree with the "Залишок до виплати" shown behind it.
    def load_month_summary
      @month = parse_month(params[:month]).beginning_of_month
      @earned = Reports::MechanicStats.new(range: @month.all_month).row_for(@mechanic).earnings
      @already_paid = PayrollPayout.where(user: @mechanic).for_month(@month).sum(:amount)
      @outstanding = @earned - @already_paid
    end

    def parse_month(value)
      value.present? ? Date.parse(value) : Date.current
    rescue Date::Error, TypeError
      Date.current
    end

    def set_mechanic
      @mechanic = User.assignable_as_mechanic.find(params[:mechanic_id])
    end

    def payout_params
      params.expect(payroll_payout: %i[ amount period_month paid_on note ])
    end
end
