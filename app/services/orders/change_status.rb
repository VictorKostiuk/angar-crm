module Orders
  # Status modal (docs/PLAN.md §6 rules 1 & 4): free movement between the 5
  # open statuses, logged to order_status_changes. :closed and :cancelled are
  # NOT reachable here — they carry their own checklists/requirements and go
  # through Orders::Close / the cancellation flow instead.
  class ChangeStatus
    def self.call(...) = new(...).call

    def initialize(order:, status:, user:, comment: nil)
      @order = order
      @status = status.to_s
      @user = user
      @comment = comment
    end

    def call
      unless Order::OPEN_STATUSES.include?(@status) && @order.open_status?
        @order.errors.add(:status, "недоступний для цього замовлення")
        return @order
      end

      return @order if @order.status == @status # no-op: nothing changed, nothing to log

      # Built via OrderStatusChange.new (not @order.order_status_changes.new)
      # so it isn't added to @order's association target — otherwise saving
      # @order below would autosave-cascade into this record and produce a
      # confusing duplicate "order status changes is invalid" error on @order.
      change = OrderStatusChange.new(order: @order, user: @user, from_status: @order.status, to_status: @status, comment: @comment)

      ActiveRecord::Base.transaction do
        raise ActiveRecord::Rollback unless change.save && @order.update(status: @status)
      end

      @order.errors.add(:base, change.errors.full_messages.to_sentence) if change.errors.any?
      @order
    end
  end
end
