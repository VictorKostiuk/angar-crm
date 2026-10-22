class Client < ApplicationRecord
  has_many :bikes, dependent: :destroy
  has_many :orders, dependent: :restrict_with_error
  # A discount pinned to this client, applied to their orders automatically.
  belongs_to :discount, optional: true

  normalizes :name, with: ->(name) { name.strip.squeeze(" ") }
  normalizes :phone, with: ->(phone) { Client.normalize_phone(phone) }
  normalizes :email, with: ->(email) { email.strip.downcase }

  validates :name, presence: true
  validates :phone, presence: true, uniqueness: true, format: { with: /\A\d{12}\z/, message: "недійсний номер телефону" }

  # Phone-substring matching only kicks in at 4+ digits — a 1-2 digit query
  # is too short to mean anything as a phone fragment (any 12-digit number
  # is overwhelmingly likely to contain any given single digit somewhere),
  # so a shorter numeric query falls through to (and correctly finds
  # nothing in) the name search instead of returning nearly every client.
  scope :search, ->(query) {
    return all if query.blank?

    digits = query.gsub(/\D/, "")
    if digits.present? && digits.length >= 4
      where("phone LIKE ?", "%#{digits}%")
    else
      where("name ILIKE ?", "%#{query}%")
    end
  }

  # Lifetime spend on services across closed orders. Summed from the work lines
  # rather than orders.works_total: a discount depends on this number now, and a
  # cached column that drifted would quietly change what a client pays (D30).
  def services_spent
    OrderWork.joins(:order).merge(Order.closed.where(client_id: id)).sum(:total)
  end

  def loyalty_percent
    Clients::LoyaltyTier.percent_for(services_spent)
  end

  def self.normalize_phone(phone)
    digits = phone.to_s.gsub(/\D/, "")
    digits = "38#{digits}" if digits.start_with?("0") && digits.length == 10
    digits
  end

  def formatted_phone
    Client.format_phone(phone)
  end

  # "380501234567" -> "+380 50 123 45 67". Class-level so a renter's phone,
  # which never passes through Client, reads the same way a client's does.
  def self.format_phone(phone)
    return phone if phone.blank? || phone.length != 12

    "+#{phone[0..2]} #{phone[3..4]} #{phone[5..7]} #{phone[8..9]} #{phone[10..11]}"
  end
end
