class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :assigned_orders, class_name: "Order", foreign_key: :mechanic_id, inverse_of: :mechanic
  has_many :accepted_orders, class_name: "Order", foreign_key: :accepted_by_id, inverse_of: :accepted_by
  has_many :payroll_payouts, dependent: :restrict_with_error

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  enum :role, { mechanic: 0, admin: 1, owner: 2 }

  validates :name, presence: true
  validates :email_address, presence: true, uniqueness: true
  validates :payroll_percent, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }

  scope :active, -> { where(active: true) }
end
