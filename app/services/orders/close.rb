module Orders
  # Close modal (docs/PLAN.md §6 rules 2 & 3, 7). blockers is exposed
  # separately from call so the close modal can render the checklist without
  # attempting (and failing) an actual close.
  class Close
    def self.call(...) = new(...).call

    def initialize(order:)
      @order = order
    end

    def call
      return @order unless blockers.empty?

      ActiveRecord::Base.transaction do
        # mechanic_id isn't part of the money path, so RecalculateTotals
        # doesn't need to fire per line here — update_all is a deliberate,
        # one-off bypass of the OrderWork callbacks (§6 rule 7 backfill).
        @order.order_works.where(mechanic_id: nil).update_all(mechanic_id: @order.mechanic_id)
        consume_parts_stock
        @order.update!(status: :closed, closed_at: Time.current)
      end

      @order
    end

    def blockers
      return [ "Замовлення вже закрито або скасовано" ] unless @order.open_status?
      return [ "Клієнт ще не приїхав — спершу позначте прийом велосипеда" ] if @order.booked?

      list = []
      list << "Замовлення не оплачено" unless @order.paid?
      list << "Не призначено механіка замовлення" if @order.mechanic_id.nil?
      list << "До замовлення не додано жодної послуги чи запчастини" if @order.order_works.none? && @order.order_parts.none?
      list
    end

    private
      # D26: catalog-linked parts consume stock on close (custom/non-catalog
      # lines have no part_id, nothing to decrement). Never blocks the close.
      # Relies on the same open_status? guard as the rest of #call for
      # double-close idempotency — a repeat close short-circuits in
      # `blockers` before this ever runs again, so stock only ever moves once.
      def consume_parts_stock
        @order.order_parts.where.not(part_id: nil).each do |order_part|
          order_part.part.stock_movements.create!(kind: :consumption, quantity: -order_part.quantity, order: @order)
        end
      end
  end
end
