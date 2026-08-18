module Finances
  # Single source of truth for "how much is still owed to this mechanic for
  # this month" (docs/PLAN.md D29) — shared by the mechanic card display and
  # the record-payout form's prefill, so they can't disagree. Deliberately
  # month-only: comparing a month's obligation against a week's or custom
  # range's payout sum would produce a plausible-looking but meaningless
  # number, so callers must not use this for non-month periods.
  class OutstandingPayroll
    def self.call(...) = new(...).call

    def initialize(mechanic:, month: Date.current)
      @mechanic = mechanic
      @month = month.beginning_of_month
    end

    def call
      obligation = Reports::MechanicStats.new(range: @month.all_month).row_for(@mechanic).payout
      paid = PayrollPayout.where(user: @mechanic).for_month(@month).sum(:amount)
      obligation - paid
    end
  end
end
