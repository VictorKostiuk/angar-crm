class Part < ApplicationRecord
  belongs_to :category
  belongs_to :supplier, optional: true
  has_many :stock_movements, dependent: :destroy

  normalizes :name, with: ->(name) { name.strip.squeeze(" ") }

  validates :name, presence: true
  validates :base_price, numericality: { greater_than_or_equal_to: 0 }
  validates :purchase_price, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :min_stock_level, numericality: { greater_than_or_equal_to: 0, only_integer: true }
  validate :category_must_be_a_part_category

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:position, :name) }
  scope :search, ->(query) { query.present? ? where("name ILIKE ?", "%#{query}%") : all }
  # min_stock_level: 0 means "no threshold set" (the column default), not
  # "warn the instant stock hits zero" — without the > 0 guard, every part
  # that's never had stock tracked (quantity: 0, level: 0) would count as
  # low stock from day one, which is noise, not a warning.
  scope :low_stock, -> { where("min_stock_level > 0 AND stock_quantity <= min_stock_level") }

  def low_stock?
    min_stock_level.positive? && stock_quantity <= min_stock_level
  end

  private
    def category_must_be_a_part_category
      errors.add(:category, "має бути категорією деталей") if category && !category.part?
    end
end
