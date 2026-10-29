# The «Записи» calendar: a month grid, the chosen day's schedule, and the form
# that books a slot. Open to every role — whoever answers the phone books.
class BookingsController < ApplicationController
  UPCOMING_LIMIT = 10

  def index
    @month = parse_month(params[:month]) || Date.current.beginning_of_month

    grid = @month.beginning_of_week(:monday)..@month.end_of_month.end_of_week(:monday)
    hours = WorkingHour.all.index_by(&:weekday)
    exceptions = ScheduleException.where(date: grid).index_by(&:date)
    @days = grid.map { |date| Bookings::Day.new(date, hours: hours[date.wday], exception: exceptions[date]) }

    # One query for the month's counts, bucketed in Ruby so the day boundary is
    # Kyiv's rather than the database's.
    @counts = Order.where(scheduled_at: grid.first.beginning_of_day..grid.last.end_of_day)
                   .where.not(status: :cancelled).pluck(:scheduled_at)
                   .map(&:to_date).tally

    @date = parse_date(params[:date])
    @date = default_date unless @date&.beginning_of_month == @month
    @day = Bookings::Day.new(@date, hours: hours[@date.wday], exception: exceptions[@date])

    # Today's still count: a client who has not turned up yet is late, not gone.
    @upcoming = Order.booked.where(scheduled_at: Time.current.beginning_of_day..)
                     .includes(:client, :bike, :maintenance_type).order(:scheduled_at).limit(UPCOMING_LIMIT)
    @types = MaintenanceType.active.ordered
  end

  def new
    @order = Order.new
    @client = params[:client_id].present? ? Client.find(params[:client_id]) : nil
    load_form(date: parse_date(params[:date]) || Date.current)
  end

  def create
    @type = MaintenanceType.active.find_by(id: params[:maintenance_type_id])
    scheduled_at = params[:scheduled_at].presence && Time.zone.parse(params[:scheduled_at])

    order = Orders::Create.call(
      accepted_by: Current.user,
      client_id: params[:client_id], client_name: params[:client_name], client_phone: params[:client_phone],
      bike_id: params[:bike_id], bike_name: params[:bike_name],
      problem: params[:problem], comment: params[:comment],
      telegram_username: params[:telegram_username],
      booking: { scheduled_at: scheduled_at, maintenance_type: @type, channel: "crm" }
    )

    if order.persisted?
      redirect_to bookings_path(month: order.scheduled_at.strftime("%Y-%m"), date: order.scheduled_at.to_date),
                  notice: "Записано на #{l order.scheduled_at, format: '%d.%m.%Y %H:%M'}."
    else
      @order = order
      @client = order.client&.persisted? ? order.client : nil
      load_form(date: scheduled_at&.to_date || parse_date(params[:date]) || Date.current, selected: scheduled_at)
      render :new, status: :unprocessable_entity
    end
  end

  # The free start times for a date and type, swapped into the form's
  # "booking_slots" frame whenever either changes.
  def slots
    load_form(date: parse_date(params[:date]) || Date.current, selected: params[:selected].presence && Time.zone.parse(params[:selected]))
    render partial: "bookings/slots", locals: { day: @day, type: @type, selected: @selected }
  end

  private
    # The current month opens on today. Another month opens on its first
    # booking, else its first working day: the 1st is often a Sunday, and an
    # empty «Вихідний» panel reads as "nothing booked this month" (D65).
    def default_date
      return Date.current if @month == Date.current.beginning_of_month

      in_month = @days.select { |day| day.date.beginning_of_month == @month }
      (in_month.find { |day| @counts[day.date] } || in_month.find(&:open?) || in_month.first).date
    end

    def load_form(date:, selected: nil)
      @types = MaintenanceType.active.ordered
      @type ||= @types.find { |type| type.id.to_s == params[:maintenance_type_id].to_s } || @types.first
      @day = Bookings::Day.new(date)
      @selected = selected
    end

    def parse_date(value)
      Date.iso8601(value.to_s) if value.present?
    rescue Date::Error
      nil
    end

    def parse_month(value)
      Date.strptime(value.to_s, "%Y-%m") if value.present?
    rescue Date::Error
      nil
    end
end
