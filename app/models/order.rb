class Order < ApplicationRecord
  belongs_to :client, counter_cache: true
  belongs_to :bike
  belongs_to :mechanic, class_name: "User", optional: true
  belongs_to :accepted_by, class_name: "User"

  has_many :order_works, -> { order(:position) }, dependent: :destroy, inverse_of: :order
  has_many :order_parts, -> { order(:position) }, dependent: :destroy, inverse_of: :order
  has_many :order_status_changes, -> { order(created_at: :desc) }, dependent: :destroy, inverse_of: :order

  # NOTE: the "new order" status is intentionally NOT named :new — Rails enum
  # generates a class-level scope with that name, which would silently shadow
  # ActiveRecord::Base.new and break every Order.new(...) call in the app.
  enum :status, { intake: 0, waiting_approval: 1, in_progress: 2, waiting_parts: 3, waiting_pickup: 4, closed: 5, cancelled: 6 }
  enum :payment_status, { unpaid: 0, paid: 1 }
  enum :payment_method, { cash: 0, card: 1, transfer: 2 }, prefix: true

  # Statuses reachable through the "change status" modal. :closed is only
  # reachable via Orders::Close, :cancelled only via the cancellation flow —
  # both require their own checklists/reasons, not a free-form status pick.
  OPEN_STATUSES = %w[ intake waiting_approval in_progress waiting_parts waiting_pickup ]

  scope :open_orders, -> { where(status: OPEN_STATUSES) }

  validates :accepted_at, presence: true
  validates :cancel_reason, presence: true, if: :cancelled?
  validates :payment_method, presence: true, if: :paid?
  validate :bike_belongs_to_client

  def open_status?
    OPEN_STATUSES.include?(status)
  end

  private
    def bike_belongs_to_client
      return if bike.nil? || client.nil? || bike.client_id == client_id

      errors.add(:bike, "належить іншому клієнту")
    end
end
