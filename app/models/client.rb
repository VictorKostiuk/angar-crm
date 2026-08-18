class Client < ApplicationRecord
  has_many :bikes, dependent: :destroy
  has_many :orders, dependent: :restrict_with_error

  normalizes :name, with: ->(name) { name.strip.squeeze(" ") }
  normalizes :phone, with: ->(phone) { Client.normalize_phone(phone) }
  normalizes :email, with: ->(email) { email.strip.downcase }

  validates :name, presence: true
  validates :phone, presence: true, uniqueness: true, format: { with: /\A\d{12}\z/, message: "недійсний номер телефону" }

  scope :search, ->(query) {
    return all if query.blank?

    digits = query.gsub(/\D/, "")
    if digits.present?
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
