module Clients
  # Shop policy, in code: spend this much on services over all closed orders and
  # every future order gets this % off its services. Highest matching tier wins.
  #
  # Thresholds and rates live here rather than in the database — they are a
  # standing policy, not per-client data. Moving them to a settings screen is a
  # small change if the shop starts varying them.
  class LoyaltyTier
    # [ lifetime spend on services, % off services ]
    TIERS = [ [ 20_000, 10 ], [ 15_000, 5 ] ].freeze

    def self.percent_for(services_spent)
      TIERS.find { |threshold, _percent| services_spent >= threshold }&.last || 0
    end

    # What the client is working toward, for the hint on their card.
    def self.next_tier_for(services_spent)
      TIERS.reverse.find { |threshold, _percent| services_spent < threshold }
    end
  end
end
