class PayrollPayout < ApplicationRecord
  belongs_to :user
  belongs_to :recorded_by, class_name: "User"

  validates :amount, numericality: { greater_than: 0 }
  validates :period_month, presence: true
  validate :user_must_be_a_mechanic

  before_validation :normalize_period_month

  scope :ordered, -> { order(period_month: :desc, created_at: :desc) }
  scope :for_month, ->(date) { where(period_month: date.beginning_of_month) }

  private
    def normalize_period_month
      self.period_month = period_month.beginning_of_month if period_month.present?
    end

    def user_must_be_a_mechanic
      errors.add(:user, "має бути механіком") if user && !user.mechanic?
    end
end
