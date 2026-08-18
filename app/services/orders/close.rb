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
        @order.update!(status: :closed, closed_at: Time.current)
      end

      @order
    end

    def blockers
      return [ "Замовлення вже закрито або скасовано" ] unless @order.open_status?

      list = []
      list << "Замовлення не оплачено" unless @order.paid?
      list << "Не призначено механіка замовлення" if @order.mechanic_id.nil?
      list << "До замовлення не додано жодної роботи чи деталі" if @order.order_works.none? && @order.order_parts.none?
      list
    end
  end
end
