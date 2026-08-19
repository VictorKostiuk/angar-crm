class Part < ApplicationRecord
  belongs_to :category
  belongs_to :supplier, optional: true
  has_many :stock_movements, dependent: :destroy

  normalizes :name, with: ->(name) { name.strip.squeeze(" ") }

  validates :name, presence: true
  validates :base_price, numericality: { greater_than_or_equal_to: 0 }
  validates :purchase_price, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validate :category_must_be_a_part_category

  after_update :backfill_missed_expenses, if: :saved_change_to_purchase_price?

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:position, :name) }
  scope :search, ->(query) { query.present? ? where("name ILIKE ?", "%#{query}%") : all }

  private
    def category_must_be_a_part_category
      errors.add(:category, "має бути категорією запчастин") if category && !category.part?
    end

    # D28's known gap: consumption before purchase_price was set never got
    # an expense. Setting/changing the price can't rewrite the past, but it
    # can catch every consumption movement still missing one and log it now,
    # using today's date and the price you just entered.
    def backfill_missed_expenses
      return if purchase_price.blank?

      stock_movements.consumption.where.missing(:expense).find_each do |movement|
        Finances::LogExpenseFromConsumption.call(movement)
      end
    end
end
