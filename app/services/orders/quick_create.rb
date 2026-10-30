module Orders
  # «Швидкий сервіс» (D71): a job done while the client waits — pump the tyres,
  # adjust the brakes, fit a tube. One form gives the mechanic, the services and
  # the materials; the order is created paid and closed in the same
  # transaction, with no client or bike to enter.
  #
  # It goes through Orders::Close like any other order, so the mechanic's work
  # lines, the parts commission, stock consumption and the goods cost all land
  # exactly where a regular order's do. Returns the order: persisted and closed,
  # or unsaved with the reasons in errors and the rows as they were typed.
  class QuickCreate
    def self.call(...) = new(...).call

    def initialize(attributes:, accepted_by:)
      @attributes = attributes.to_h.symbolize_keys
      @accepted_by = accepted_by
    end

    def call
      now = Time.current
      # Paid on the spot, with no payment method asked for: nothing reports by
      # method, and a guessed one would be made-up data.
      order = Order.new(@attributes.merge(quick: true, status: :in_progress, accepted_by: @accepted_by, accepted_at: now,
                                          payment_status: :paid, paid_at: now))

      # Checked before the lines validate: without a mechanic every work line
      # would also refuse itself, burying the one message that matters.
      order.errors.add(:base, "Оберіть механіка") if order.mechanic_id.blank?
      order.errors.add(:base, "Додайте хоча б одну послугу або матеріал") if lines(order).empty?
      return order if order.errors.any?

      unless order.valid?
        messages = messages_for(order)
        order.errors.clear
        messages.each { |message| order.errors.add(:base, message) }
        return order
      end

      Order.transaction do
        order.save!
        close = Orders::Close.new(order: order)
        if close.blockers.any?
          close.blockers.each { |message| order.errors.add(:base, message) }
          raise ActiveRecord::Rollback
        end
        close.call
      end

      order
    end

    private
      def lines(order)
        order.order_works.to_a + order.order_parts.to_a
      end

      # A line's own complaint, said about that line — the nested-attribute
      # wording («Order works price…») means nothing at the counter.
      def messages_for(order)
        own = order.errors.reject { |error| error.attribute.to_s.include?(".") }.map(&:full_message)
        named = { OrderWork => "Послуга", OrderPart => "Матеріал" }
        own + lines(order).select { |line| line.errors.any? }.map do |line|
          "#{named.fetch(line.class)} «#{line.name.presence || "без назви"}»: #{line.errors.full_messages.to_sentence}"
        end
      end
  end
end
