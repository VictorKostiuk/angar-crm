module Orders
  # Status modal (docs/PLAN.md §6 rules 1 & 4): free movement between the
  # open statuses (into «Запис» only from the calendar, D61), logged to order_status_changes. :closed and :cancelled are
  # NOT reachable here — they carry their own checklists/requirements and go
  # through Orders::Close / the cancellation flow instead.
  class ChangeStatus
    def self.call(...) = new(...).call

    def initialize(order:, status:, user:, comment: nil, mechanic_id: :unchanged)
      @order = order
      @status = status.to_s
      @user = user
      @comment = comment
      @mechanic_id = mechanic_id
    end

    def call
      unless Order::OPEN_STATUSES.include?(@status) && @order.open_status?
        @order.errors.add(:status, "недоступний для цього замовлення")
        return @order
      end

      # «Запис» is only ever entered through the booking calendar, which sets
      # the time and checks the slot. Moving an order back into it from here
      # would leave a booking with no appointment.
      if @status == "booked" && !@order.booked?
        @order.errors.add(:status, "«Запис» створюється через календар записів")
        return @order
      end

      # Leaving «Запис» is the client walking in: that is when the bike was
      # accepted, and by whoever is at the counter — not when or by whom the
      # booking was typed in. «Дата прийому», its filter and accepted_count
      # all read these.
      if @order.booked? && @status != "booked"
        @order.accepted_at = Time.current
        @order.accepted_by = @user
      end

      # Picking who does the job is part of moving it into work, so it rides the
      # same transaction rather than a second, separately-failing update.
      @order.mechanic_id = @mechanic_id.presence unless @mechanic_id == :unchanged

      if @order.status == @status # no-op on status; a mechanic pick still saves
        @order.save if @order.changed?
        return @order
      end

      # Built via OrderStatusChange.new (not @order.order_status_changes.new)
      # so it isn't added to @order's association target — otherwise saving
      # @order below would autosave-cascade into this record and produce a
      # confusing duplicate "order status changes is invalid" error on @order.
      change = OrderStatusChange.new(order: @order, user: @user, from_status: @order.status, to_status: @status, comment: @comment)

      ActiveRecord::Base.transaction do
        @order.status = @status
        raise ActiveRecord::Rollback unless change.save && @order.save
      end

      @order.errors.add(:base, change.errors.full_messages.to_sentence) if change.errors.any?
      @order
    end
  end
end
