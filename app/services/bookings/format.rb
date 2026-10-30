module Bookings
  module Format
    # 90 -> "1 год 30 хв", 60 -> "1 год", 45 -> "45 хв"
    def self.duration(minutes)
      hours, mins = minutes.to_i.divmod(60)
      [ ("#{hours} год" if hours.positive?), ("#{mins} хв" if mins.positive?) ].compact.join(" ").presence || "0 хв"
    end
  end
end
