class Service < ApplicationRecord
  belongs_to :category

  normalizes :name, with: ->(name) { name.strip.squeeze(" ") }

  validates :name, presence: true
  validates :base_price, numericality: { greater_than_or_equal_to: 0 }
  validate :category_must_be_a_service_category

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:position, :name) }
  scope :search, ->(query) { query.present? ? where("name ILIKE ?", "%#{query}%") : all }

  private
    def category_must_be_a_service_category
      errors.add(:category, "має бути категорією робіт") if category && !category.service?
    end
end
