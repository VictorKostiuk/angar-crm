module Orders
  # The single place that decides what an order's discount is. Three candidates,
  # and the one worth most to the client wins (D47):
  #
  #   manual  — a discount picked on the order itself
  #   client  — a discount pinned to the client
  #   loyalty — earned automatically by lifetime spend on services
  #
  # Called from Orders::RecalculateTotals, so the discount is re-derived every
  # time the lines change: a percentage can no longer go stale against a total
  # that grew after it was picked.
  class ApplyDiscount
    Result = Struct.new(:amount, :source, keyword_init: true)
    NONE = Result.new(amount: 0, source: nil)

    def self.call(...) = new(...).call

    def initialize(order:, works_total:, parts_total:)
      @order = order
      @works_total = works_total
      @parts_total = parts_total
    end

    def call
      candidates.compact.select { |c| c.amount.positive? }.max_by(&:amount) || NONE
    end

    private
      def candidates
        [ from(@order.discount_record, "manual"),
          from(@order.client&.discount, "client"),
          loyalty ]
      end

      def from(discount, source)
        return if discount.blank?

        Result.new(amount: discount.amount_for(works_total: @works_total, parts_total: @parts_total),
                   source: source)
      end

      # Earned automatically, so it has no catalogue entry — a percentage off
      # services, matching the threshold that earns it.
      def loyalty
        percent = @order.client&.loyalty_percent.to_i
        return if percent.zero?

        Result.new(amount: (@works_total * percent / 100).round(2), source: "loyalty")
      end
  end
end
