class Order < ApplicationRecord
  # Optional only for a quick service (D71), which has neither — see the
  # presence check below, which keeps them required on every other order.
  belongs_to :client, counter_cache: true, optional: true
  belongs_to :bike, optional: true
  belongs_to :mechanic, class_name: "User", optional: true
  # `discount` holds the computed amount; `discount_record` remembers which
  # catalog entry produced it, so the picker can show what was chosen.
  belongs_to :discount_record, class_name: "Discount", optional: true
  belongs_to :accepted_by, class_name: "User"
  # What a booked client is coming in for. Optional: a walk-in has none.
  belongs_to :maintenance_type, optional: true

  has_many :order_works, -> { order(:position) }, dependent: :destroy, inverse_of: :order
  has_many :order_parts, -> { order(:position) }, dependent: :destroy, inverse_of: :order
  has_many :order_status_changes, -> { order(created_at: :desc) }, dependent: :destroy, inverse_of: :order
  has_many_attached :photos

  # The quick-service form enters its lines with the order in one go (D71). An
  # untouched row — nothing picked, nothing typed — is just a spare row.
  accepts_nested_attributes_for :order_works, reject_if: ->(attrs) { attrs[:service_id].blank? && attrs[:name].blank? }
  accepts_nested_attributes_for :order_parts, reject_if: ->(attrs) { attrs[:part_id].blank? && attrs[:name].blank? }

  # NOTE: the "new order" status is intentionally NOT named :new — Rails enum
  # generates a class-level scope with that name, which would silently shadow
  # ActiveRecord::Base.new and break every Order.new(...) call in the app.
  # booked is first in the hash so it reads first in every dropdown; its
  # integer is 7 because the others are already stored.
  enum :status, { booked: 7, intake: 0, waiting_approval: 1, in_progress: 2, waiting_parts: 3, waiting_pickup: 4, closed: 5, cancelled: 6 }
  enum :payment_status, { unpaid: 0, paid: 1 }
  enum :payment_method, { cash: 0, card: 1, transfer: 2 }, prefix: true

  # Statuses reachable through the "change status" modal. :closed is only
  # reachable via Orders::Close, :cancelled only via the cancellation flow —
  # both require their own checklists/reasons, not a free-form status pick.
  OPEN_STATUSES = %w[ booked intake waiting_approval in_progress waiting_parts waiting_pickup ]
  # Open, minus «Запис»: the bike is physically in the shop. A booking is
  # open — it can be edited, cancelled, shown on the board — but the bike has
  # not arrived, so it must not read «У майстерні» or count as work in hand.
  IN_SHOP_STATUSES = OPEN_STATUSES - %w[ booked ]

  scope :open_orders, -> { where(status: OPEN_STATUSES) }
  scope :in_shop, -> { where(status: IN_SHOP_STATUSES) }
  # Came in through the booking calendar, whatever has happened to it since —
  # what the «Запис» filter means on Замовлення and in Архів.
  scope :via_booking, -> { where.not(scheduled_at: nil) }
  scope :walk_in, -> { where(scheduled_at: nil) }
  scope :quick, -> { where(quick: true) }

  # Closed and cancelled orders are settled records — their lines, money,
  # mechanic and photos are frozen. Enforced in the controllers, not just by
  # hiding buttons: a hidden button is not a guard.
  def editable?
    open_status?
  end

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
    relation = left_joins(:client, :bike)

    if digits.present? && digits == query.delete("#").gsub(/\s/, "")
      if digits.length >= 4
        relation.where("orders.number::text = :digits OR clients.phone LIKE :like", digits: digits, like: "%#{digits}%")
      else
        relation.where("orders.number::text = ?", digits)
      end
    else
      relation.where("clients.name ILIKE :q OR bikes.name ILIKE :q", q: "%#{query}%")
    end
  }

  validates :accepted_at, presence: true
  # The same check belongs_to makes by default, waived for a quick service.
  validates :client, :bike, presence: { message: :required }, unless: :quick?
  validates :mechanic, presence: true, if: :quick?
  validates :cancel_reason, presence: true, if: :cancelled?
  # A quick service is paid on the spot and nobody is asked how (D71).
  validates :payment_method, presence: true, if: -> { paid? && !quick? }
  validate :bike_belongs_to_client
  validate :photos_must_be_images
  validate :mechanic_must_be_a_mechanic
  validates :scheduled_at, :booking_minutes, presence: true, if: :booked?
  validates :booking_channel, inclusion: { in: %w[ crm telegram ] }, allow_nil: true
  validate :slot_must_be_free, if: -> { booked? && (will_save_change_to_scheduled_at? || will_save_change_to_booking_minutes?) }

  # order_works/order_parts trigger Orders::RecalculateTotals on their own
  # save/destroy (§6). Picking a different discount needs its own trigger, or
  # the change silently no-ops on the stored total. Keyed on the *record*, not
  # on `discount` — that column is this callback's own output now (D47).
  after_save :recalculate_totals, if: :saved_change_to_discount_record_id?

  def open_status?
    OPEN_STATUSES.include?(status)
  end

  def via_booking?
    scheduled_at.present?
  end

  def via_telegram?
    booking_channel == "telegram"
  end

  def booking_ends_at
    scheduled_at + booking_minutes.to_i.minutes if scheduled_at
  end

  private
    # The same check the calendar uses to offer times, so a stale form or a
    # second person booking the same slot is refused rather than overbooked.
    def slot_must_be_free
      return if scheduled_at.blank? || booking_minutes.blank?
      return if Bookings::Day.new(scheduled_at.to_date).free?(scheduled_at, booking_minutes, except: self)

      errors.add(:scheduled_at, "— цей час уже зайнятий або поза робочими годинами")
    end

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
      errors.add(:mechanic, "має бути механіком") if mechanic && !mechanic.assignable_as_mechanic?
    end

    def photos_must_be_images
      return unless photos.attached?

      errors.add(:photos, "має бути зображенням") unless photos.all? { |photo| photo.content_type.start_with?("image/") }
    end
end
