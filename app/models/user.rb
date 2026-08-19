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

  # Who can be assigned work — a superset of role == mechanic. The owner (or an
  # admin) who also turns wrenches ticks works_as_mechanic and shows up in the
  # mechanic dropdowns, the roster and the payroll reports, without inheriting
  # a mechanic's *permissions*: access control stays keyed on `role` (§7), so
  # an owner still sees the whole roster rather than being bounced to their own
  # card. Everything that assigns or reports on work keys on this instead of
  # `mechanic?` — see Order#mechanic_must_be_a_mechanic for why that matters.
  scope :assignable_as_mechanic, -> { where(role: :mechanic).or(where(works_as_mechanic: true)) }

  def assignable_as_mechanic?
    mechanic? || works_as_mechanic?
  end
end
