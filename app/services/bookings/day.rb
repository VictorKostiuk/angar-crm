module Bookings
  # Everything about one calendar date's booking schedule: its hours (the
  # weekday's, overridden by a ScheduleException), what is already booked, and
  # which start times are still free for a given duration.
  #
  # The single source of availability — the calendar, the booking form, the
  # server-side check on save and (later) the Telegram bot all ask this, so the
  # times offered and the times accepted cannot disagree.
  class Day
    Booking = Struct.new(:order, :starts_at, :ends_at, keyword_init: true)

    attr_reader :date

    # hours/exception can be passed in preloaded (the month grid builds 42 of
    # these); :lookup fetches them. nil is a real value — "no row" = closed.
    def initialize(date, hours: :lookup, exception: :lookup)
      @date = date.to_date
      @hours = hours == :lookup ? WorkingHour.find_by(weekday: @date.wday) : hours
      @exception = exception == :lookup ? ScheduleException.find_by(date: @date) : exception
    end

    def exception = @exception

    # A special day with its own hours opens even a normal day off — a Sunday
    # before the season, say. Otherwise it only adjusts an open weekday.
    def open?
      return false if @exception&.closed?
      return false if (@hours.nil? || @hours.closed?) && !own_hours?

      closes_minute > opens_minute
    end

    def own_hours?
      @exception.present? && @exception.opens_minute.present? && @exception.closes_minute.present?
    end

    def shortened?
      open? && @exception.present?
    end

    def opens_minute = @exception&.opens_minute || @hours&.opens_minute
    def closes_minute = @exception&.closes_minute || @hours&.closes_minute
    def capacity = @exception&.capacity || @hours&.capacity || 1
    def slot_minutes = @hours&.slot_minutes || 30

    def opens_at = at(opens_minute)
    def closes_at = at(closes_minute)

    # Every order holding time on this date. Cancelled ones free their slot; an
    # order whose client already arrived still holds it — the bike is on the
    # stand for the time that was booked.
    def bookings(except: nil)
      @bookings ||= Order.where(scheduled_at: date.all_day).where.not(status: :cancelled)
                         .includes(:client, :bike, :maintenance_type).order(:scheduled_at).to_a
      list = @bookings.reject { |order| order.id == except&.id && except.persisted? }
      list.map { |order| Booking.new(order: order, starts_at: order.scheduled_at, ends_at: order.booking_ends_at) }
    end

    # Bookings left outside the hours after a day was shortened or closed —
    # shown flagged in the day view rather than silently dropped.
    def out_of_hours?(booking)
      !open? || booking.starts_at < opens_at || booking.ends_at > closes_at
    end

    # Start times at which a booking of `minutes` fits: inside the hours, not
    # in the past, and never pushing overlap past capacity.
    def free_starts(minutes, now: Time.current, except: nil)
      return [] unless open? && minutes.to_i.positive?

      taken = bookings(except: except)
      starts = []
      start = opens_at
      while start + minutes.minutes <= closes_at
        starts << start if start > now && fits?(start, start + minutes.minutes, taken)
        start += slot_minutes.minutes
      end
      starts
    end

    def free?(starts_at, minutes, now: Time.current, except: nil)
      ends_at = starts_at + minutes.minutes
      open? && starts_at >= opens_at && ends_at <= closes_at && starts_at > now &&
        fits?(starts_at, ends_at, bookings(except: except))
    end

    private
      def at(minute)
        date.in_time_zone.change(hour: minute / 60, min: minute % 60) if minute
      end

      # Overlap inside [from, to) can only peak at `from` or where another
      # booking begins, so those are the only instants worth counting at.
      # Checking at grid steps instead would miss bookings made under an older
      # step size.
      def fits?(from, to, taken)
        points = [ from ] + taken.map(&:starts_at).select { |t| t > from && t < to }
        points.all? do |instant|
          taken.count { |b| b.starts_at <= instant && instant < b.ends_at } < capacity
        end
      end
  end
end
