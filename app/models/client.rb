class Client < ApplicationRecord
  has_many :bikes, dependent: :destroy
  has_many :orders, dependent: :restrict_with_error

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

  def self.normalize_phone(phone)
    digits = phone.to_s.gsub(/\D/, "")
    digits = "38#{digits}" if digits.start_with?("0") && digits.length == 10
    digits
  end

  # "380501234567" -> "+380 50 123 45 67"
  def formatted_phone
    return phone if phone.blank? || phone.length != 12

    "+#{phone[0..2]} #{phone[3..4]} #{phone[5..7]} #{phone[8..9]} #{phone[10..11]}"
  end
end
