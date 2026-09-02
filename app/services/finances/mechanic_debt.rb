module Finances
  # The standing balance owed to each mechanic: everything earned on closed
  # orders, ever, minus everything ever paid out.
  #
  # Deliberately period-independent, unlike OutstandingPayroll (D29), which
  # reconciles one month against that month's payouts. A debt does not reset
  # when you change the period filter — money owed for June is still owed while
  # you are looking at August — so this is the number to show as "Борг".
  class MechanicDebt
    ALL_TIME = (Time.zone.at(0)..)

    Row = Struct.new(:mechanic, :earned, :paid, keyword_init: true) do
      def balance
        earned - paid
      end

      def owed?
        balance.positive?
      end
    end

    def self.call(...) = new(...).call

    def initialize(mechanic: nil)
      @mechanic = mechanic
    end

    def call
      paid_by_user = payouts_scope.group(:user_id).sum(:amount)

      stats.map do |row|
        Row.new(mechanic: row.mechanic, earned: row.earnings, paid: paid_by_user.fetch(row.mechanic.id, 0))
      end
    end

    # Positive balances only: one mechanic's overpayment must not quietly
    # cancel out what the shop still owes another.
    def total
      call.sum { |row| [ row.balance, 0 ].max }
    end

    private
      def stats
        rows = Reports::MechanicStats.new(range: ALL_TIME).call
        @mechanic ? rows.select { |row| row.mechanic == @mechanic } : rows
      end

      def payouts_scope
        @mechanic ? PayrollPayout.where(user: @mechanic) : PayrollPayout.all
      end
  end
end
