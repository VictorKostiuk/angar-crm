# Opening hours are stored as minutes since midnight (see the AddBookings
# migration on why not `time` columns). This gives each one an "HH:MM" reader
# and writer, which is what <input type="time"> sends and expects.
#
#   minute_of_day :opens   # opens_minute <-> opens_at ("10:00")
module MinuteOfDay
  extend ActiveSupport::Concern

  def self.format(minutes)
    return if minutes.nil?

    Kernel.format("%02d:%02d", minutes / 60, minutes % 60)
  end

  def self.parse(value)
    return if value.blank?

    hours, mins = value.to_s.split(":").map(&:to_i)
    hours * 60 + mins.to_i
  end

  class_methods do
    def minute_of_day(*names)
      names.each do |name|
        define_method("#{name}_at") { MinuteOfDay.format(public_send("#{name}_minute")) }
        define_method("#{name}_at=") { |value| public_send("#{name}_minute=", MinuteOfDay.parse(value)) }
      end
    end
  end
end
