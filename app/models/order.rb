class Order < ApplicationRecord
  belongs_to :client, counter_cache: true
  belongs_to :bike
  belongs_to :mechanic, class_name: "User", optional: true
  belongs_to :accepted_by, class_name: "User"

  has_many :order_works, -> { order(:position) }, dependent: :destroy, inverse_of: :order
  has_many :order_parts, -> { order(:position) }, dependent: :destroy, inverse_of: :order
  has_many :order_status_changes, -> { order(created_at: :desc) }, dependent: :destroy, inverse_of: :order
  has_many_attached :photos

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

  # A purely-numeric query (optionally "#123") matches the order number
  # exactly, or a client phone substring; anything else matches the client
  # name — same digits-vs-text branch as Client.search, mirrored for
  # consistency. The phone-substring match only kicks in at 4+ digits: a
  # short numeric query like "2" is a perfectly normal order number (#002),
  # but as a *phone* substring it matches nearly every client (any 12-digit
  # phone number is overwhelmingly likely to contain any single digit
  # somewhere) — caught by a flaky test where a low sequence-assigned order
  # number happened to match an unrelated client's phone digits.
  scope :search, ->(query) {
    return all if query.blank?

    digits = query.gsub(/\D/, "")
    relation = left_joins(:client)

    if digits.present? && digits == query.delete("#").gsub(/\s/, "")
      if digits.length >= 4
        relation.where("orders.number::text = :digits OR clients.phone LIKE :like", digits: digits, like: "%#{digits}%")
      else
        relation.where("orders.number::text = ?", digits)
      end
    else
      relation.where("clients.name ILIKE ?", "%#{query}%")
    end
  }

  validates :accepted_at, presence: true
  validates :cancel_reason, presence: true, if: :cancelled?
  validates :payment_method, presence: true, if: :paid?
  validate :bike_belongs_to_client
  validate :photos_must_be_images
  validate :mechanic_must_be_a_mechanic

  # order_works/order_parts trigger Orders::RecalculateTotals on their own
  # save/destroy (§6) — discount lives on the order itself, so it needs its
  # own trigger, or editing it silently no-ops on the stored total.
  after_save :recalculate_totals, if: :saved_change_to_discount?

  def open_status?
    OPEN_STATUSES.include?(status)
  end

  private
    def recalculate_totals
      Orders::RecalculateTotals.call(self)
    end

    def bike_belongs_to_client
      return if bike.nil? || client.nil? || bike.client_id == client_id

      errors.add(:bike, "належить іншому клієнту")
    end

    # A non-mechanic (admin/owner) assigned as mechanic_id would silently
    # drop out of every mechanic-keyed report/payroll table, since those are
    # all keyed by User.mechanic — happened for real once (an owner account
    # got picked from an unfiltered dropdown before this validation existed).
    def mechanic_must_be_a_mechanic
      errors.add(:mechanic, "має бути механіком") if mechanic && !mechanic.mechanic?
    end

    def photos_must_be_images
      return unless photos.attached?

      errors.add(:photos, "має бути зображенням") unless photos.all? { |photo| photo.content_type.start_with?("image/") }
    end
end
