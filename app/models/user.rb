class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  enum :role, { mechanic: 0, admin: 1, owner: 2 }

  validates :name, presence: true
  validates :payroll_percent, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }

  scope :active, -> { where(active: true) }
end
