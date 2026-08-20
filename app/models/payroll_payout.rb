class PayrollPayout < ApplicationRecord
  belongs_to :user
  belongs_to :recorded_by, class_name: "User"

  validates :amount, numericality: { greater_than: 0 }
  validates :period_month, presence: true
  validates :paid_on, presence: true
  validate :user_must_be_a_mechanic

  before_validation :normalize_period_month
  before_validation :default_paid_on

  # <input type="month"> posts "YYYY-MM", which Active Record typecasts to nil —
  # the form would silently blank the period. Only the month is ever stored, so
  # accept that shape and pin it to the first of the month.
  def period_month=(value)
    value = "#{value}-01" if value.is_a?(String) && value.match?(/\A\d{4}-\d{2}\z/)
    super
  end

  scope :ordered, -> { order(paid_on: :desc, created_at: :desc) }
  # Attribution, not cash flow: which month's earnings a payout settles. The
  # mechanic card's "Залишок за <місяць>" reconciles against this, while
  # Фінанси counts money that actually moved, by paid_on.
  scope :for_month, ->(date) { where(period_month: date.beginning_of_month) }
  scope :paid_in, ->(range) { where(paid_on: range) }

  private
    # Recording a payout is something you do on the day you pay, so an omitted
    # or cleared date means today rather than an error.
    def default_paid_on
      self.paid_on ||= Date.current
    end

    def normalize_period_month
      self.period_month = period_month.beginning_of_month if period_month.present?
    end

    def user_must_be_a_mechanic
      errors.add(:user, "має бути механіком") if user && !user.assignable_as_mechanic?
    end
end
